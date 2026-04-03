defmodule Mix.Tasks.Beacon.Gen.ProxyEndpoint.Docs do
  @moduledoc false

  def short_doc do
    "Generates a ProxyEndpoint in the current project, enabling Beacon to serve sites at multiple hosts."
  end

  def example do
    "mix beacon.gen.proxy_endpoint"
  end

  def long_doc do
    """
    #{short_doc()}

    ## Example

    ```bash
    #{example()}
    ```

    ## Options

    * `--secret-key-base` (optional) - The value to use for secret_key_base in your app config.
      By default, Beacon will generate a new value and update all existing config to match that value.
      If you don't want this behavior, copy the secret_key_base from your app config and provide it here.
    * `--signing-salt` (optional) - The value to use for signing_salt in your app config.
      By default, Beacon will generate a new value and update all existing config to match that value.
      But in order to avoid connection errors for existing clients, it's recommened to copy the `signing_salt` from your app config and provide it here.
    * `--session-key` (optional) - The value to use for key in the session config. Defaults to `"_your_app_name_key"`
    * `--session-same-site` (optional) - Set the cookie session SameSite attributes. Defaults to `"Lax"`

    """
  end
end

defmodule Mix.Tasks.Beacon.Gen.ProxyEndpoint do
  @shortdoc "#{__MODULE__.Docs.short_doc()}"

  @moduledoc __MODULE__.Docs.long_doc()

  use Mix.Task

  def run(_argv) do
    Mix.shell().error("""
    The task 'beacon.gen.proxy_endpoint' is not available.

    Please follow the installation guide at: https://hexdocs.pm/beacon
    """)

    exit({:shutdown, 1})
  end
end
