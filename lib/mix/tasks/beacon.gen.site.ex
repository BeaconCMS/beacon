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

  * `--site` or `-s` (required) - The name of your site. Should not contain special characters nor start with "beacon_"
  * `--path` or `-p` (optional, defaults to "/") - Where your site will be mounted. Follows the same convention as Phoenix route prefixes.
  * `--host` or `-h` (optional) - If provided, a new endpoint will be created for this site with the given URL.

  """

  @doc false
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :beacon,
      example: @example,
      schema: [site: :string, path: :string, host: :string],
      aliases: [s: :site, p: :path, h: :host],
      defaults: [path: "/"],
      required: [:site]
    }
  end

  @doc false
  def igniter(igniter) do
    options = igniter.args.options
    site = Keyword.fetch!(options, :site) |> String.to_atom()
    path = Keyword.fetch!(options, :path)
    host = Keyword.get(options, :host)
    validate_options!(site, path, host)

    otp_app = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    {igniter, router} = Beacon.Igniter.select_router!(igniter)
    repo = Igniter.Project.Module.module_name(igniter, "Repo")

    igniter
    |> create_migration(repo)
    |> add_use_beacon_in_router(router)
    |> add_beacon_pipeline_in_router(router)
    |> mount_site_in_router(router, site, path, host)
    |> add_site_config_in_config_runtime(site, repo, router, host)
    |> add_beacon_config_in_app_supervisor(site, repo, router)
    |> maybe_create_proxy_endpoint(host)
    |> maybe_create_new_endpoint(host, otp_app, web_module)
    |> maybe_configure_new_endpoint(host, otp_app)
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

  defp validate_options!(site, path, _host) do
    cond do
      !Beacon.Types.Site.valid?(site) -> raise_with_help!("Invalid site name. It should not contain special characters.", site, path)
      !Beacon.Types.Site.valid_name?(site) -> raise_with_help!("Invalid site name. The site name can't start with \"beacon_\".", site, path)
      !Beacon.Types.Site.valid_path?(path) -> raise_with_help!("Invalid path value. It should start with /.", site, path)
      :else -> :ok
    end
  end

  defp raise_with_help!(msg, site, path) do
    Mix.raise("""
    #{msg}

    For example:

        mix beacon.gen.site --site blog
        or
        mix beacon.gen.site --site blog --path "/blog_path"

    Got:

      site: #{inspect(site)}
      path: #{inspect(path)}

    """)
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
            if host,
              do: [with_pipelines: [:browser, :beacon], router: router, arg2: [host: host]],
              else: [with_pipelines: [:browser, :beacon], router: router]

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
        host -> {igniter, new_endpoint_module(igniter, host)}
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

  defp add_beacon_config_in_app_supervisor(igniter, site, repo, router) do
    {igniter, endpoint} = Beacon.Igniter.select_endpoint!(igniter, router)

    Igniter.Project.Application.add_new_child(
      igniter,
      {Beacon,
       {:code,
        quote do
          [sites: [Application.fetch_env!(:beacon, unquote(site))]]
        end}},
      after: [repo, endpoint],
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

  defp maybe_create_proxy_endpoint(igniter, nil), do: igniter
  defp maybe_create_proxy_endpoint(igniter, _host), do: Igniter.compose_task(igniter, "beacon.gen.proxy_endpoint")

  defp maybe_create_new_endpoint(igniter, nil, _, _), do: igniter

  defp maybe_create_new_endpoint(igniter, host, otp_app, web_module) do
    Igniter.Project.Module.create_module(
      igniter,
      new_endpoint_module(igniter, host),
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

  defp maybe_configure_new_endpoint(igniter, nil, _), do: igniter

  defp maybe_configure_new_endpoint(igniter, host, otp_app) do
    new_endpoint = new_endpoint_module(igniter, host)
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
    |> Igniter.Project.Config.configure("config.exs", otp_app, [new_endpoint, :live_view, :signing_salt], "O68x1k5A")
    # dev.exs
    # TODO: ensure port valid
    |> Igniter.Project.Config.configure(
      "dev.exs",
      otp_app,
      [new_endpoint, :http],
      {:code, Sourceror.parse_string!("[ip: {127, 0, 0, 1}, port: 4002]")}
    )
    |> Igniter.Project.Config.configure("dev.exs", otp_app, [new_endpoint, :check_origin], {:code, Sourceror.parse_string!("false")})
    |> Igniter.Project.Config.configure("dev.exs", otp_app, [new_endpoint, :code_reloader], {:code, Sourceror.parse_string!("true")})
    |> Igniter.Project.Config.configure("dev.exs", otp_app, [new_endpoint, :debug_errors], {:code, Sourceror.parse_string!("true")})
    # TODO: ensure secret key valid
    |> Igniter.Project.Config.configure(
      "dev.exs",
      otp_app,
      [new_endpoint, :secret_key_base],
      "A0DSgxjGCYZ6fCIrBlg6L+qC/cdoFq5Rmomm53yacVmN95Wcpl57Gv0sTJjKjtIp"
    )
    # TODO: beacon_tailwind_config watcher
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
    |> Igniter.Project.Config.configure_runtime_env(:prod, otp_app, [new_endpoint, :url, :port], 443)
    |> Igniter.Project.Config.configure_runtime_env(:prod, otp_app, [new_endpoint, :url, :scheme], "https")
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [new_endpoint, :http, :ip],
      {:code, Sourceror.parse_string!("{0, 0, 0, 0, 0, 0, 0, 0}")}
    )
    |> Igniter.Project.Config.configure_runtime_env(:prod, otp_app, [new_endpoint, :http, :port], {:code, Sourceror.parse_string!("port")})
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [new_endpoint, :secret_key_base],
      {:code, Sourceror.parse_string!("secret_key_base")}
    )
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [proxy_endpoint, :check_origin],
      [],
      updater: fn zipper -> Igniter.Code.List.append_to_list(zipper, host) end
    )
  end

  defp maybe_add_new_endpoint_to_application(igniter, nil, _), do: igniter

  defp maybe_add_new_endpoint_to_application(igniter, host, repo) do
    Igniter.Project.Application.add_new_child(igniter, new_endpoint_module(igniter, host), after: [repo, Phoenix.PubSub, Finch])
  end

  defp new_endpoint_module(igniter, host) do
    [implicit_prefix | _] = String.split(host, ".")
    Igniter.Libs.Phoenix.web_module_name(igniter, "#{String.capitalize(implicit_prefix)}Endpoint")
  end
end
