defmodule Mix.Tasks.Beacon.Gen.Site do
  use Igniter.Mix.Task

  @example "mix beacon.gen.site --site my_site --path / --host my_site.com"
  @shortdoc "Generates a new Beacon site in the current project."

  @test? Beacon.Config.env_test?()

  @moduledoc """
  #{@shortdoc}

  Remember to execute [`mix beacon.install`](https://hexdocs.pm/beacon/Mix.Tasks.Beacon.Install.html)
  first if this is the first site you're generating in your project and you have not installed Beacon yet.

  ## Example

  ```bash
  #{@example}
  ```

  ## Options

  * `--site` (required) - The name of your site. Should not contain special characters nor start with "beacon_"
  * `--path` (optional) - Where your site will be mounted. Follows the same convention as Phoenix route prefixes. Defaults to `"/"`
  * `--host` (optional) - If provided, site will be served on that host.
  * `--port` (optional) - The port to use for http requests. Only needed when `--host` is provided.  If no port is given, one will be chosen at random.
  * `--secure-port` (optional) - The port to use for https requests. Only needed when `--host` is provided.  If no port is given, one will be chosen at random.
  * `--secret-key-base` (optional) - The value to use for secret_key_base in your app config.
                                     By default, Beacon will generate a new value and update all existing config to match that value.
                                     If you don't want this behavior, copy the secret_key_base from your app config and provide it here.
  * `--signing-salt` (optional) - The value to use for signing_salt in your app config.
                                  By default, Beacon will generate a new value and update all existing config to match that value.
                                  but in order to avoid connection errors for existing clients, it's recommened to copy the `signing_salt` from your app config and provide it here.
  * `--session-key` (optional) - The value to use for key in the session config. Defaults to `"_your_app_name_key"`
  * `--session-same-site` (optional) - Set the cookie session SameSite attributes. Defaults to "Lax"

  """

  @doc false
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :beacon,
      example: @example,
      schema: [
        site: :string,
        path: :string,
        host: :string,
        port: :integer,
        secure_port: :integer,
        secret_key_base: :string,
        signing_salt: :string,
        session_key: :string,
        session_same_site: :string
      ],
      defaults: [path: "/"],
      required: [:site]
    }
  end

  @doc false
  def igniter(igniter) do
    options = igniter.args.options
    argv = igniter.args.argv

    site = Keyword.fetch!(options, :site) |> validate_site!()
    path = Keyword.fetch!(options, :path) |> validate_path!()
    host = Keyword.get(options, :host) |> validate_host!()

    port = Keyword.get_lazy(options, :port, fn -> Enum.random(4101..4999) end)
    secure_port = Keyword.get_lazy(options, :secure_port, fn -> Enum.random(8444..8999) end)

    otp_app = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    {igniter, router} = Beacon.Igniter.select_router!(igniter)
    repo = Igniter.Project.Module.module_name(igniter, "Repo")

    igniter
    |> create_migration(repo)
    |> add_use_beacon_in_router(router)
    |> add_beacon_pipeline_in_router(router)
    |> mount_site_in_router(router, site, path, host)
    |> add_site_config_in_config_runtime(site, repo, router)
    |> add_beacon_config_in_app_supervisor(site, repo)
    |> create_proxy_endpoint(argv)
    |> create_new_endpoint(site, otp_app, web_module)
    |> configure_new_endpoint(site, host, otp_app, port, secure_port)
    |> update_session_options(otp_app)
    |> add_new_endpoint_to_application(site, repo)
    |> Igniter.add_notice("""
    Site #{inspect(site)} generated successfully.

    The site is usually mounted in the same scope as the one used by the host application,
    in a best effort case to avoid conflicts, but conflicts can still happen or the site
    might not be mounted in the most appropriate order for your application.

    See the Route Precedence section in the Beacon.Router docs for more information.

    https://hexdocs.pm/beacon/Beacon.Router.html
    """)
  end

  defp validate_site!(site) do
    Beacon.Types.Site.valid?(site) ||
      Mix.raise("""
      invalid site

      It should not contain special characters
      """)

    Beacon.Types.Site.valid_name?(site) ||
      Mix.raise("""
      invalid site

      The site name can't start with \"beacon_\".
      """)

    String.to_atom(site)
  end

  defp validate_path!(path) do
    Beacon.Types.Site.valid_path?(path) ||
      Mix.raise("""
      invalid path

      It should start with /
      """)

    path
  end

  defp validate_host!(nil = host), do: host

  defp validate_host!(host) do
    case domain_prefix(host) do
      {:ok, _} ->
        host

      _ ->
        Mix.raise("""
        invalid host
        """)
    end
  end

  defp domain_prefix(host) do
    with {:ok, %{host: host}} <- URI.new("//" <> host),
         [prefix, _] <- String.split(host, ".", trim: 2, parts: 2) do
      {:ok, prefix}
    else
      _ -> :error
    end
  end

  defp add_use_beacon_in_router(igniter, router) do
    Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
      case Igniter.Code.Module.move_to_use(zipper, Beacon.Router) do
        {:ok, zipper} ->
          {:ok, zipper}

        _ ->
          with {:ok, zipper} <- Igniter.Libs.Phoenix.move_to_router_use(igniter, zipper) do
            {:ok, Igniter.Code.Common.add_code(zipper, "use Beacon.Router")}
          end
      end
    end)
  end

  defp add_beacon_pipeline_in_router(igniter, router) do
    Igniter.Libs.Phoenix.add_pipeline(
      igniter,
      :beacon,
      "plug Beacon.Plug",
      router: router
    )
  end

  defp create_migration(igniter, repo) do
    timestamp = if @test?, do: [timestamp: 0], else: []

    Igniter.Libs.Ecto.gen_migration(
      igniter,
      repo,
      "create_beacon_tables",
      [
        body: """
        def up, do: Beacon.Migration.up()
        def down, do: Beacon.Migration.down()
        """,
        on_exists: :skip
      ] ++ timestamp
    )
  end

  defp mount_site_in_router(igniter, router, site, path, host) do
    case Igniter.Project.Module.find_module(igniter, router) do
      {:ok, {_igniter, _source, zipper}} ->
        exists? =
          Sourceror.Zipper.find(
            zipper,
            &match?({:beacon_site, _, [{_, _, [^path]}, [{{_, _, [:site]}, {_, _, [^site]}}]]}, &1)
          )

        if exists? do
          Igniter.add_warning(
            igniter,
            "Site already exists: #{site}, skipping creation."
          )
        else
          content =
            """
            beacon_site #{inspect(path)}, site: #{inspect(site)}
            """

          opts =
            if host do
              [
                with_pipelines: [:browser, :beacon],
                router: router,
                arg2: [alias: Igniter.Libs.Phoenix.web_module(igniter), host: ["localhost", host]]
              ]
            else
              [
                with_pipelines: [:browser, :beacon],
                router: router,
                arg2: [alias: Igniter.Libs.Phoenix.web_module(igniter)]
              ]
            end

          Igniter.Libs.Phoenix.append_to_scope(igniter, "/", content, opts)
        end

      _ ->
        :skip
    end
  end

  defp add_site_config_in_config_runtime(igniter, site, repo, router) do
    endpoint = new_endpoint_module!(igniter, site)

    Igniter.Project.Config.configure(
      igniter,
      "runtime.exs",
      :beacon,
      [site],
      {:code,
       Sourceror.parse_string!("""
       [site: :#{site}, repo: #{inspect(repo)}, endpoint: #{inspect(endpoint)}, router: #{inspect(router)}]
       """)}
    )
  end

  defp add_beacon_config_in_app_supervisor(igniter, site, repo) do
    Igniter.Project.Application.add_new_child(
      igniter,
      {Beacon,
       {:code,
        quote do
          [sites: [Application.fetch_env!(:beacon, unquote(site))]]
        end}},
      after: [repo],
      opts_updater: fn zipper ->
        with {:ok, zipper} <-
               Igniter.Code.Keyword.put_in_keyword(
                 zipper,
                 [:sites],
                 Sourceror.parse_string!("[Application.fetch_env!(:beacon, :#{site})]"),
                 fn zipper ->
                   exists? =
                     Sourceror.Zipper.find(
                       zipper,
                       &match?({{_, _, [{_, _, [:Application]}, :fetch_env!]}, _, [{_, _, [:beacon]}, {_, _, [^site]}]}, &1)
                     )

                   if exists? do
                     {:ok, zipper}
                   else
                     Igniter.Code.List.append_to_list(
                       zipper,
                       Sourceror.parse_string!("Application.fetch_env!(:beacon, :#{site})")
                     )
                   end
                 end
               ) do
          {:ok, zipper}
        else
          :error -> {:warning, ["Failed to automatically add your site."]}
        end
      end
    )
  end

  defp create_proxy_endpoint(igniter, argv), do: Igniter.compose_task(igniter, "beacon.gen.proxy_endpoint", argv)

  defp create_new_endpoint(igniter, site, otp_app, web_module) do
    proxy_endpoint_module_name = Igniter.Libs.Phoenix.web_module_name(igniter, "ProxyEndpoint")

    Igniter.Project.Module.create_module(
      igniter,
      new_endpoint_module!(igniter, site),
      """
      use Phoenix.Endpoint, otp_app: #{inspect(otp_app)}

      @session_options Application.compile_env!(#{inspect(otp_app)}, :session_options)

      def proxy_endpoint, do: #{inspect(proxy_endpoint_module_name)}

      # socket /live must be in the proxy endpoint

      # Serve at "/" the static files from "priv/static" directory.
      #
      # You should set gzip to true if you are running phx.digest
      # when deploying your static files in production.
      plug Plug.Static,
        at: "/",
        from: #{inspect(otp_app)},
        gzip: false,
        # robots.txt is served by Beacon
        only: ~w(assets fonts images favicon.ico)

      # Code reloading can be explicitly enabled under the
      # :code_reloader configuration of your endpoint.
      if code_reloading? do
        socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
        plug Phoenix.LiveReloader
        plug Phoenix.CodeReloader
        plug Phoenix.Ecto.CheckRepoStatus, otp_app: #{inspect(otp_app)}
      end

      plug Plug.RequestId
      plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Phoenix.json_library()

      plug Plug.MethodOverride
      plug Plug.Head
      plug Plug.Session, @session_options
      plug #{inspect(web_module)}.Router
      """
    )
  end

  defp configure_new_endpoint(igniter, site, host, otp_app, port, secure_port) do
    new_endpoint = new_endpoint_module!(igniter, site)
    error_html = "Beacon.Web.ErrorHTML"
    pubsub = Igniter.Project.Module.module_name(igniter, "PubSub")

    # TODO: replace the first two steps with `configure/6` once the `:after` option is allowed
    igniter
    |> then(
      &if(Igniter.Project.Config.configures_key?(&1, "config.exs", otp_app, new_endpoint),
        do: &1,
        else:
          Igniter.update_elixir_file(&1, "config/config.exs", fn zipper ->
            {:ok,
             zipper
             |> Beacon.Igniter.move_to_variable!(:signing_salt)
             |> Igniter.Project.Config.modify_configuration_code(
               [new_endpoint],
               otp_app,
               Sourceror.parse_string!("""
               [
                 url: [host: "localhost"],
                 adapter: Bandit.PhoenixAdapter,
                 render_errors: [
                   formats: [html: #{error_html}],
                   layout: false
                 ],
                 pubsub_server: #{inspect(pubsub)},
                 live_view: [signing_salt: signing_salt]
               ]
               """)
             )}
          end)
      )
    )
    |> then(
      &if(Igniter.Project.Config.configures_key?(&1, "dev.exs", otp_app, new_endpoint),
        do: &1,
        else:
          Igniter.update_elixir_file(&1, "config/dev.exs", fn zipper ->
            {:ok,
             zipper
             |> Beacon.Igniter.move_to_variable!(:secret_key_base)
             |> Igniter.Project.Config.modify_configuration_code(
               [new_endpoint],
               otp_app,
               Sourceror.parse_string!("""
               [
                 http: [ip: {127, 0, 0, 1}, port: #{port}],
                 check_origin: false,
                 code_reloader: true,
                 debug_errors: true,
                 secret_key_base: secret_key_base,
                 watchers: [
                   esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
                   tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
                 ]
               ]
               """)
             )}
          end)
      )
    )
    |> Igniter.Project.Config.configure_runtime_env(:prod, otp_app, [new_endpoint, :url, :host], host || {:code, Sourceror.parse_string!("host")})
    |> Igniter.Project.Config.configure_runtime_env(:prod, otp_app, [new_endpoint, :url, :port], secure_port)
    |> Igniter.Project.Config.configure_runtime_env(:prod, otp_app, [new_endpoint, :url, :scheme], "https")
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [new_endpoint, :http],
      {:code, Sourceror.parse_string!("[ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: #{port}]")}
    )
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [new_endpoint, :secret_key_base],
      {:code, Sourceror.parse_string!("secret_key_base")}
    )
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [new_endpoint, :server],
      {:code, Sourceror.parse_string!("!!System.get_env(\"PHX_SERVER\")")}
    )
  end

  defp update_session_options(igniter, otp_app) do
    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      otp_app,
      [:session_options, :signing_salt],
      {:code, Sourceror.parse_string!("signing_salt")}
    )
  end

  defp add_new_endpoint_to_application(igniter, site, repo) do
    Igniter.Project.Application.add_new_child(igniter, new_endpoint_module!(igniter, site), after: [repo, Phoenix.PubSub, Beacon])
  end

  @doc false
  def new_endpoint_module!(site) when is_atom(site) do
    site
    |> to_string()
    |> String.split(~r/[^[:alnum:]]+/)
    |> Enum.map_join("", &String.capitalize/1)
    |> Kernel.<>("Endpoint")
  end

  @doc false
  def new_endpoint_module!(igniter, site) when is_atom(site) do
    suffix = new_endpoint_module!(site)
    Igniter.Libs.Phoenix.web_module_name(igniter, suffix)
  end
end
