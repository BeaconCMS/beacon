defmodule Mix.Tasks.Beacon.Gen.ProxyEndpoint do
  use Igniter.Mix.Task

  @example "mix beacon.gen.proxy_endpoint"
  @shortdoc "TODO"

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
      schema: [key: :string, signing_salt: :string, same_site: :string],
      defaults: [same_site: "Lax"]
    }
  end

  @doc false
  def igniter(igniter) do
    otp_app = Igniter.Project.Application.app_name(igniter)
    {igniter, router} = Beacon.Igniter.select_router!(igniter)
    {igniter, fallback_endpoint} = Beacon.Igniter.select_endpoint(igniter, router, "Select a fallback endpoint (default app Endpoint):")
    proxy_endpoint_module_name = Igniter.Libs.Phoenix.web_module_name(igniter, "ProxyEndpoint")
    signing_salt = Keyword.get_lazy(igniter.args.options, :signing_salt, fn -> random_string(8) end)

    igniter
    |> create_proxy_endpoint_module(otp_app, fallback_endpoint, proxy_endpoint_module_name)
    |> add_session_options_config(otp_app, signing_salt, igniter.args.options)
    |> add_proxy_endpoint_config(otp_app, proxy_endpoint_module_name, signing_salt)
    |> update_fallback_endpoint_signing_salt(otp_app, fallback_endpoint, signing_salt)
    |> Igniter.add_notice("""
    TODO
    """)
  end

  defp create_proxy_endpoint_module(igniter, otp_app, fallback_endpoint, proxy_endpoint_module_name) do
    if Igniter.Project.Module.module_exists(igniter, proxy_endpoint_module_name) do
      Igniter.add_notice(igniter, """
      Module #{inspect(proxy_endpoint_module_name)} already exists. Skipping.
      """)
    else
      Igniter.Project.Module.create_module(igniter, proxy_endpoint_module_name, """
        use Beacon.ProxyEndpoint,
          otp_app: #{inspect(otp_app)},
          session_options: Application.compile_env!(#{inspect(otp_app)}, :session_options),
          fallback: #{inspect(fallback_endpoint)}
      """)
    end
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

  def add_proxy_endpoint_config(igniter, otp_app, proxy_endpoint_module_name, signing_salt) do
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
  end

  defp update_fallback_endpoint_signing_salt(igniter, otp_app, fallback_endpoint, signing_salt) do
    fallback_endpoint = String.to_atom("#{fallback_endpoint}")
    dbg(fallback_endpoint)

    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      otp_app,
      [fallback_endpoint, :live_view, :signing_salt],
      signing_salt
    )
  end

  # https://github.com/phoenixframework/phoenix/blob/c9b431f3a5d3bdc6a1d0ff3c29a229226e991195/installer/lib/phx_new/generator.ex#L451
  defp random_string(length),
    do: :crypto.strong_rand_bytes(length) |> Base.encode64() |> binary_part(0, length)
end
