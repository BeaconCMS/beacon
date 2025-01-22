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
  * `--path` (optional, defaults to "/") - Where your site will be mounted. Follows the same convention as Phoenix route prefixes.
  * `--host` (optional) - If provided, a new endpoint will be created for this site with the given URL.
  * `--port` (optional) - The port to use for http requests. Only needed when `--host` is provided.  If no port is given, one will be chosen at random.
  * `--secure-port` (optional) - The port to use for https requests. Only needed when `--host` is provided.  If no port is given, one will be chosen at random.
  * `--secret-key-base` (optional) - The value to use for secret_key_base in your app config. By default, Beacon will generate a new value and update all existing config to match that value. If you don't want this behavior, copy the secret_key_base from your app config and provide it here.
  * `--signing-salt` (optional) The value to use for signing_salt in your app config. By default, Beacon will generate a new value and update all existing config to match that value. If you don't want this behavior, copy the signing_salt from your app config and provide it here.

  """

  @doc false
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :beacon,
      example: @example,
      schema: [site: :string, path: :string, host: :string, port: :integer, secure_port: :integer, secret_key_base: :string, signing_salt: :string],
      defaults: [path: "/"],
      required: [:site]
    }
  end

  @doc false
  def igniter(igniter) do
    options = igniter.args.options
    site = Keyword.fetch!(options, :site) |> validate_site!()
    path = Keyword.fetch!(options, :path) |> validate_path!()
    host = Keyword.get(options, :host) |> validate_host!()

    port = Keyword.get_lazy(options, :port, fn -> Enum.random(4101..4999) end)
    secure_port = Keyword.get_lazy(options, :secure_port, fn -> Enum.random(8444..8999) end)
    signing_salt = Keyword.get_lazy(options, :signing_salt, fn -> random_string(8) end)
    secret_key_base = Keyword.get_lazy(options, :secret_key_base, fn -> random_string(64) end)

    otp_app = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    {igniter, router} = Beacon.Igniter.select_router!(igniter)
    {igniter, existing_endpoints} = Igniter.Libs.Phoenix.endpoints_for_router(igniter, router)
    repo = Igniter.Project.Module.module_name(igniter, "Repo")

    igniter
    |> create_migration(repo)
    |> add_use_beacon_in_router(router)
    |> add_beacon_pipeline_in_router(router)
    |> mount_site_in_router(router, site, path, host)
    |> add_site_config_in_config_runtime(site, repo, router, host)
    |> add_beacon_config_in_app_supervisor(site, repo)
    |> maybe_create_proxy_endpoint(host, signing_salt, secret_key_base)
    |> maybe_create_new_endpoint(host, otp_app, web_module)
    |> maybe_configure_new_endpoint(host, otp_app, port, secure_port, secret_key_base, signing_salt)
    |> maybe_update_existing_endpoints(host, otp_app, existing_endpoints, signing_salt, secret_key_base)
    |> maybe_update_session_options(host, otp_app, signing_salt)
    |> maybe_add_new_endpoint_to_application(host, repo)
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

  defp add_site_config_in_config_runtime(igniter, site, repo, router, host) do
    {igniter, endpoint} =
      case host do
        nil -> Beacon.Igniter.select_endpoint!(igniter, router)
        host -> {igniter, new_endpoint_module!(igniter, host)}
      end

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

  defp maybe_create_proxy_endpoint(igniter, nil, _, _), do: igniter

  defp maybe_create_proxy_endpoint(igniter, _host, signing_salt, secret_key_base),
    do: Igniter.compose_task(igniter, "beacon.gen.proxy_endpoint", ~w(--signing-salt #{signing_salt} --secret-key-base #{secret_key_base}))

  defp maybe_create_new_endpoint(igniter, nil, _, _), do: igniter

  defp maybe_create_new_endpoint(igniter, host, otp_app, web_module) do
    Igniter.Project.Module.create_module(
      igniter,
      new_endpoint_module!(igniter, host),
      """
      use Phoenix.Endpoint, otp_app: #{inspect(otp_app)}

      @session_options Application.compile_env!(#{inspect(otp_app)}, :session_options)

      # socket /live must be in the proxy endpoint

      # Serve at "/" the static files from "priv/static" directory.
      #
      # You should set gzip to true if you are running phx.digest
      # when deploying your static files in production.
      plug Plug.Static,
        at: "/",
        from: #{inspect(otp_app)},
        gzip: false,
        only: #{inspect(web_module)}.static_paths()

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

  defp maybe_configure_new_endpoint(igniter, nil, _, _, _, _, _), do: igniter

  defp maybe_configure_new_endpoint(igniter, host, otp_app, port, secure_port, secret_key_base, signing_salt) do
    new_endpoint = new_endpoint_module!(igniter, host)
    proxy_endpoint = Igniter.Libs.Phoenix.web_module_name(igniter, "ProxyEndpoint")
    error_html = Igniter.Libs.Phoenix.web_module_name(igniter, "ErrorHTML")
    error_json = Igniter.Libs.Phoenix.web_module_name(igniter, "ErrorJSON")
    pubsub = Igniter.Project.Module.module_name(igniter, "PubSub")

    igniter
    # config.exs
    |> Igniter.Project.Config.configure("config.exs", otp_app, [new_endpoint, :url, :host], "localhost")
    |> Igniter.Project.Config.configure("config.exs", otp_app, [new_endpoint, :adapter], {:code, Sourceror.parse_string!("Bandit.PhoenixAdapter")})
    |> Igniter.Project.Config.configure(
      "config.exs",
      otp_app,
      [new_endpoint, :render_errors],
      {:code,
       Sourceror.parse_string!("""
       [
         formats: [html: #{inspect(error_html)}, json: #{inspect(error_json)}],
         layout: false
       ]
       """)}
    )
    |> Igniter.Project.Config.configure("config.exs", otp_app, [new_endpoint, :pubsub_server], pubsub)
    |> Igniter.Project.Config.configure("config.exs", otp_app, [new_endpoint, :live_view, :signing_salt], signing_salt)
    # dev.exs
    |> Igniter.Project.Config.configure(
      "dev.exs",
      otp_app,
      [new_endpoint, :http],
      {:code, Sourceror.parse_string!("[ip: {127, 0, 0, 1}, port: #{port}]")}
    )
    |> Igniter.Project.Config.configure("dev.exs", otp_app, [new_endpoint, :check_origin], {:code, Sourceror.parse_string!("false")})
    |> Igniter.Project.Config.configure("dev.exs", otp_app, [new_endpoint, :code_reloader], {:code, Sourceror.parse_string!("true")})
    |> Igniter.Project.Config.configure("dev.exs", otp_app, [new_endpoint, :debug_errors], {:code, Sourceror.parse_string!("true")})
    |> Igniter.Project.Config.configure("dev.exs", otp_app, [new_endpoint, :secret_key_base], secret_key_base)
    |> Igniter.Project.Config.configure(
      "dev.exs",
      otp_app,
      [new_endpoint, :watchers],
      {:code,
       Sourceror.parse_string!("""
       [
         esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
         tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
       ]
       """)}
    )
    # runtime.exs
    |> Igniter.Project.Config.configure_runtime_env(:prod, otp_app, [new_endpoint, :url, :host], host)
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
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [proxy_endpoint, :check_origin],
      [],
      updater: fn zipper -> Igniter.Code.List.append_to_list(zipper, host) end
    )
  end

  defp maybe_update_existing_endpoints(igniter, nil, _, _, _, _), do: igniter

  defp maybe_update_existing_endpoints(igniter, _host, otp_app, existing_endpoints, signing_salt, secret_key_base) do
    Enum.reduce(existing_endpoints, igniter, fn endpoint, acc ->
      acc
      |> Igniter.Project.Config.configure("config.exs", otp_app, [endpoint, :live_view, :signing_salt], signing_salt)
      |> Igniter.Project.Config.configure("dev.exs", otp_app, [endpoint, :secret_key_base], secret_key_base)
    end)
  end

  defp maybe_update_session_options(igniter, nil, _, _), do: igniter

  defp maybe_update_session_options(igniter, _host, otp_app, signing_salt) do
    Igniter.Project.Config.configure(igniter, "config.exs", otp_app, [:session_options, :signing_salt], signing_salt)
  end

  defp maybe_add_new_endpoint_to_application(igniter, nil, _), do: igniter

  defp maybe_add_new_endpoint_to_application(igniter, host, repo) do
    Igniter.Project.Application.add_new_child(igniter, new_endpoint_module!(igniter, host), after: [repo, Phoenix.PubSub, Finch, Beacon])
  end

  defp new_endpoint_module!(igniter, host) do
    {:ok, prefix} = domain_prefix(host)

    suffix =
      prefix
      |> String.split(~r/[^[:alnum:]]+/)
      |> Enum.map_join("", &String.capitalize/1)
      |> Kernel.<>("Endpoint")

    Igniter.Libs.Phoenix.web_module_name(igniter, suffix)
  end

  # https://github.com/phoenixframework/phoenix/blob/c9b431f3a5d3bdc6a1d0ff3c29a229226e991195/installer/lib/phx_new/generator.ex#L451
  defp random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
    |> binary_part(0, length)
  end
end
