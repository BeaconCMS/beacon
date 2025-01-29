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

  ## Options

  * `--secret-key-base` (optional) - The value to use for secret_key_base in your app config.
                                     By default, Beacon will generate a new value and update all existing config to match that value. 
                                     If you don't want this behavior, copy the secret_key_base from your app config and provide it here.
  * `--signing-salt` (optional) - The value to use for signing_salt in your app config.
                                  By default, Beacon will generate a new value and update all existing config to match that value.
                                  but in order to avoid connection errors for existing clients, it's recommened to copy the `signing_salt` from your app config and provide it here.
  * `--session-key` (optional) - The value to use for key in the session config. Defaults to `"_your_app_name_key"`
  * `--same-site` (optional) - Set the cookie session SameSite attributes. Defaults to "Lax"

  """

  @doc false
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :beacon,
      example: @example,
      schema: [
        secret_key_base: :string,
        signing_salt: :string,
        session_key: :string,
        session_same_site: :string
      ],
      defaults: [session_same_site: "Lax"]
    }
  end

  @doc false
  def igniter(igniter) do
    options = igniter.args.options
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
        signing_salt = Keyword.get_lazy(options, :signing_salt, fn -> random_string(8) end)
        secret_key_base = Keyword.get_lazy(options, :secret_key_base, fn -> random_string(64) end)

        igniter
        |> create_proxy_endpoint_module(otp_app, fallback_endpoint, proxy_endpoint_module_name)
        |> add_endpoint_to_application(fallback_endpoint, proxy_endpoint_module_name)
        |> add_variables_to_config(signing_salt, secret_key_base)
        |> add_session_options_config(otp_app, igniter.args.options)
        |> update_existing_endpoints(otp_app, existing_endpoints)
        |> add_proxy_endpoint_config(otp_app, proxy_endpoint_module_name)
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
    Igniter.Project.Application.add_new_child(igniter, proxy_endpoint_module_name, after: [fallback_endpoint, Beacon])
  end

  def add_variables_to_config(igniter, signing_salt, secret_key_base) do
    igniter
    |> Igniter.update_elixir_file("config/config.exs", fn zipper ->
      case Beacon.Igniter.move_to_variable(zipper, :signing_salt) do
        {:ok, _already_exists} ->
          zipper

        :error ->
          {:ok, at_import} = Beacon.Igniter.move_to_import(zipper, Config)
          Igniter.Code.Common.add_code(at_import, "signing_salt = \"#{signing_salt}\"", placement: :after)
      end
    end)
    |> Igniter.update_elixir_file("config/dev.exs", fn zipper ->
      case Beacon.Igniter.move_to_variable(zipper, :secret_key_base) do
        {:ok, _already_exists} ->
          zipper

        :error ->
          {:ok, at_import} = Beacon.Igniter.move_to_import(zipper, Config)
          Igniter.Code.Common.add_code(at_import, "secret_key_base = \"#{secret_key_base}\"", placement: :after)
      end
    end)
  end

  def add_session_options_config(igniter, otp_app, options) do
    session_key = Keyword.get_lazy(options, :session_key, fn -> "_#{otp_app}_key" end)
    session_same_site = Keyword.get(options, :session_same_site, "Lax")

    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      otp_app,
      [:session_options],
      {:code,
       Sourceror.parse_string!("""
       [
         store: :cookie,
         key: "#{session_key}",
         signing_salt: signing_salt,
         same_site: "#{session_same_site}"
       ]
       """)}
    )
  end

  def add_proxy_endpoint_config(igniter, otp_app, proxy_endpoint_module_name) do
    igniter
    |> Igniter.update_elixir_file("config/config.exs", fn zipper ->
      {:ok,
       zipper
       |> Beacon.Igniter.move_to_variable!(:signing_salt)
       |> Igniter.Project.Config.modify_configuration_code(
         [proxy_endpoint_module_name],
         otp_app,
         Sourceror.parse_string!("""
         [adapter: Bandit.PhoenixAdapter, live_view: [signing_salt: signing_salt]]
         """)
       )}
    end)
    |> Igniter.update_elixir_file("config/dev.exs", fn zipper ->
      {:ok,
       zipper
       |> Beacon.Igniter.move_to_variable!(:secret_key_base)
       |> Igniter.Project.Config.modify_configuration_code(
         [proxy_endpoint_module_name],
         otp_app,
         Sourceror.parse_string!("""
         [
           http: [ip: {127, 0, 0, 1}, port: 4000],
           check_origin: false,
           debug_errors: true,
           secret_key_base: secret_key_base
         ]
         """)
       )}
    end)
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [proxy_endpoint_module_name, :check_origin],
      {:code, Sourceror.parse_string!("{#{inspect(proxy_endpoint_module_name)}, :check_origin, []}")}
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
    |> Igniter.Project.Config.configure_runtime_env(
      :prod,
      otp_app,
      [proxy_endpoint_module_name, :server],
      {:code, Sourceror.parse_string!("!!System.get_env(\"PHX_SERVER\")")}
    )
  end

  defp update_existing_endpoints(igniter, otp_app, existing_endpoints) do
    Enum.reduce(existing_endpoints, igniter, fn endpoint, acc ->
      acc
      |> Igniter.Project.Config.configure(
        "config.exs",
        otp_app,
        [endpoint, :live_view, :signing_salt],
        {:code, Sourceror.parse_string!("signing_salt")}
      )
      |> Igniter.Project.Config.configure("dev.exs", otp_app, [endpoint, :secret_key_base], {:code, Sourceror.parse_string!("secret_key_base")})
      |> Igniter.Project.Config.configure("dev.exs", otp_app, [endpoint, :http], [],
        updater: fn zipper ->
          if port_matches_value?(zipper, 4000) do
            {:ok, Igniter.Code.Common.replace_code(zipper, update_port(zipper, 4100))}
          else
            {:ok, zipper}
          end
        end
      )
      |> Igniter.Project.Config.configure_runtime_env(:prod, otp_app, [endpoint, :http], [],
        updater: fn zipper ->
          if port_matches_variable?(zipper) do
            {:ok, Igniter.Code.Common.replace_code(zipper, update_port(zipper, 4100))}
          else
            {:ok, zipper}
          end
        end
      )
      |> Igniter.Project.Config.configure_runtime_env(:prod, otp_app, [endpoint, :url], [],
        updater: fn zipper ->
          if port_matches_value?(zipper, 443) do
            {:ok, Igniter.Code.Common.replace_code(zipper, update_port(zipper, 8443))}
          else
            {:ok, zipper}
          end
        end
      )
      |> Igniter.Project.Module.find_and_update_module!(endpoint, fn zipper ->
        case Igniter.Code.Function.move_to_function_call(zipper, :socket, 3) do
          {:ok, zipper} ->
            # TODO: replace the node with a commented-out version of itself
            # blocked by https://github.com/ash-project/igniter/pull/200
            {:ok, Sourceror.Zipper.remove(zipper)}

          _ ->
            {:ok, zipper}
        end
      end)
      |> Igniter.Project.Module.find_and_update_module!(endpoint, fn zipper ->
        case Beacon.Igniter.move_to_constant(zipper, :session_options) do
          {:ok, zipper} ->
            new = Sourceror.parse_string!("@session_options Application.compile_env!(#{inspect(otp_app)}, :session_options)")
            {:ok, Sourceror.Zipper.replace(zipper, new)}

          _ ->
            {:ok, zipper}
        end
      end)
    end)
  end

  defp port_matches_value?(zipper, value) do
    ast =
      zipper
      |> Igniter.Code.Common.maybe_move_to_single_child_block()
      |> Sourceror.Zipper.node()

    Enum.any?(ast, &match?({{:__block__, _, [:port]}, {:__block__, _, [^value]}}, &1))
  end

  defp port_matches_variable?(zipper) do
    ast =
      zipper
      |> Igniter.Code.Common.maybe_move_to_single_child_block()
      |> Sourceror.Zipper.node()

    Enum.any?(ast, &match?({{:__block__, _, [:port]}, {:port, _, nil}}, &1))
  end

  defp update_port(zipper, value) do
    {opts, _} =
      zipper
      |> Igniter.Code.Common.maybe_move_to_single_child_block()
      |> Sourceror.Zipper.node()
      |> Code.eval_quoted(port: nil, host: :__host_placeholder__)

    opts
    |> Keyword.replace(:port, value)
    |> inspect()
    |> String.replace(":__host_placeholder__", "host")
  end

  # https://github.com/phoenixframework/phoenix/blob/c9b431f3a5d3bdc6a1d0ff3c29a229226e991195/installer/lib/phx_new/generator.ex#L451
  defp random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64(padding: false)
    |> binary_part(0, length)
  end
end
