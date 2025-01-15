defmodule Mix.Tasks.Beacon.Gen.ProxyEndpoint do
  use Igniter.Mix.Task

  require Igniter.Code.Common

  @example "mix beacon.gen.proxy_endpoint"
  @shortdoc "Generates a ProxyEndpoint in the current project, enabling Beacon to serve sites at multiple hosts."

  @moduledoc """
  #{@shortdoc}

  ## Example

  ```bash
  #{@example}
  ```
  """

  @doc false
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :beacon,
      example: @example,
      schema: [key: :string, signing_salt: :string, secret_key_base: :string, same_site: :string],
      defaults: [same_site: "Lax"]
    }
  end

  @doc false
  def igniter(igniter) do
    proxy_endpoint_module_name = Igniter.Libs.Phoenix.web_module_name(igniter, "ProxyEndpoint")

    case Igniter.Project.Module.module_exists(igniter, proxy_endpoint_module_name) do
      {true, igniter} ->
        Igniter.add_notice(igniter, """
        Module #{inspect(proxy_endpoint_module_name)} already exists. Skipping.
        """)

      {false, igniter} ->
        otp_app = Igniter.Project.Application.app_name(igniter)
        {igniter, router} = Beacon.Igniter.select_router!(igniter)
        {igniter, fallback_endpoint} = Beacon.Igniter.select_endpoint(igniter, router, "Select a fallback endpoint (default app Endpoint):")
        {igniter, existing_endpoints} = Igniter.Libs.Phoenix.endpoints_for_router(igniter, router)
        signing_salt = Keyword.get_lazy(igniter.args.argv, :signing_salt, fn -> random_string(8) end)
        secret_key_base = Keyword.get_lazy(igniter.args.argv, :secret_key_base, fn -> random_string(64) end)

        igniter
        |> create_proxy_endpoint_module(otp_app, fallback_endpoint, proxy_endpoint_module_name)
        |> add_endpoint_to_application(fallback_endpoint, proxy_endpoint_module_name)
        |> add_session_options_config(otp_app, signing_salt, igniter.args.options)
        |> update_existing_endpoints(otp_app, existing_endpoints, signing_salt)
        |> add_proxy_endpoint_config(otp_app, proxy_endpoint_module_name, signing_salt, secret_key_base)
        |> Igniter.add_notice("""
        ProxyEndpoint generated successfully.

        This enables your application to serve sites at multiple hosts, each with their own Endpoint.
        """)
    end
  end

  defp create_proxy_endpoint_module(igniter, otp_app, fallback_endpoint, proxy_endpoint_module_name) do
    Igniter.Project.Module.create_module(igniter, proxy_endpoint_module_name, """
      use Beacon.ProxyEndpoint,
        otp_app: #{inspect(otp_app)},
        session_options: Application.compile_env!(#{inspect(otp_app)}, :session_options),
        fallback: #{inspect(fallback_endpoint)}
    """)
  end

  defp add_endpoint_to_application(igniter, fallback_endpoint, proxy_endpoint_module_name) do
    Igniter.Project.Application.add_new_child(igniter, proxy_endpoint_module_name, after: [fallback_endpoint])
  end

  def add_session_options_config(igniter, otp_app, signing_salt, options) do
    key = Keyword.get_lazy(options, :key, fn -> "_#{otp_app}_key" end)
    same_site = Keyword.get(options, :same_site, "Lax")

    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      otp_app,
      [:session_options],
      {:code,
       Sourceror.parse_string!("""
       [
         store: :cookie,
         key: "#{key}",
         signing_salt: "#{signing_salt}",
         same_site: "#{same_site}"
       ]
       """)}
    )
  end

  def add_proxy_endpoint_config(igniter, otp_app, proxy_endpoint_module_name, signing_salt, secret_key_base) do
    igniter
    |> Igniter.Project.Config.configure(
      "config.exs",
      otp_app,
      [proxy_endpoint_module_name, :adapter],
      {:code, Sourceror.parse_string!("Bandit.PhoenixAdapter")}
    )
    |> Igniter.Project.Config.configure(
      "config.exs",
      otp_app,
      [proxy_endpoint_module_name, :live_view, :signing_salt],
      signing_salt
    )
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [proxy_endpoint_module_name, :check_origin],
      {:code, Sourceror.parse_string!("[]")}
    )
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [proxy_endpoint_module_name, :url],
      {:code, Sourceror.parse_string!("[port: 443, scheme: \"https\"]")}
    )
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [proxy_endpoint_module_name, :http],
      {:code, Sourceror.parse_string!("[ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port]")}
    )
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [proxy_endpoint_module_name, :secret_key_base],
      {:code, Sourceror.parse_string!("secret_key_base")}
    )
    |> Igniter.Project.Config.configure(
      "dev.exs",
      otp_app,
      [proxy_endpoint_module_name, :http],
      {:code, Sourceror.parse_string!("[ip: {127, 0, 0, 1}, port: 4000]")}
    )
    |> Igniter.Project.Config.configure("dev.exs", otp_app, [proxy_endpoint_module_name, :check_origin], {:code, Sourceror.parse_string!("false")})
    |> Igniter.Project.Config.configure("dev.exs", otp_app, [proxy_endpoint_module_name, :debug_errors], {:code, Sourceror.parse_string!("true")})
    |> Igniter.Project.Config.configure("dev.exs", otp_app, [proxy_endpoint_module_name, :secret_key_base], secret_key_base)
  end

  defp update_existing_endpoints(igniter, otp_app, existing_endpoints, signing_salt) do
    Enum.reduce(existing_endpoints, igniter, fn endpoint, acc ->
      acc
      |> Igniter.Project.Config.configure("config.exs", otp_app, [endpoint, :live_view, :signing_salt], signing_salt)
      |> Igniter.Project.Config.configure("dev.exs", otp_app, [endpoint, :http], [],
        updater: fn zipper ->
          if port_matches_value?(zipper, 4000) do
            updated_opts = update_port(zipper, 4100)
            {:ok, Igniter.Code.Common.replace_code(zipper, "#{inspect(updated_opts)}")}
          else
            {:ok, zipper}
          end
        end
      )
    end)
  end

  defp port_matches_value?(zipper, value) do
    ast =
      zipper
      |> Igniter.Code.Common.maybe_move_to_single_child_block()
      |> Sourceror.Zipper.node()

    Enum.any?(ast, &match?({{:__block__, _, [:port]}, {:__block__, _, [^value]}}, &1))
  end

  defp update_port(zipper, value) do
    {opts, _} =
      zipper
      |> Igniter.Code.Common.maybe_move_to_single_child_block()
      |> Sourceror.Zipper.node()
      |> Code.eval_quoted()

    Keyword.replace(opts, :port, value)
  end

  # https://github.com/phoenixframework/phoenix/blob/c9b431f3a5d3bdc6a1d0ff3c29a229226e991195/installer/lib/phx_new/generator.ex#L451
  defp random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
    |> binary_part(0, length)
  end
end
