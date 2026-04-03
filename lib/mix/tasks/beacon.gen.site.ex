defmodule Mix.Tasks.Beacon.Gen.Site.Docs do
  @moduledoc false

  def short_doc do
    "Generates a new Beacon site in the current project."
  end

  def example do
    "mix beacon.gen.site --site my_site"
  end

  def long_doc do
    """
    #{short_doc()}

    Remember to execute [`mix beacon.install`](https://hexdocs.pm/beacon/Mix.Tasks.Beacon.Install.html)
    first if this is the first site you're generating in your project and you have not installed Beacon yet.

    ## Examples

    ```bash
    #{example()}
    ```

    ```bash
    mix beacon.gen.site --site my_site --path / --host mysite.com
    ```

    To define a custom host to work locally and the production host:

    ```bash
    mix beacon.gen.site --site my_site --path / --host-dev local.mysite.com --host mysite.com
    ```

    ## Using --host-dev for Multiple Sites

    The `--host-dev` option is particularly useful when you need to run multiple sites at the root path (`/`). Without custom hosts, all sites would try to serve at `localhost:4000/`, which would cause conflicts.

    For example, if you have two sites:

    ```bash
    mix beacon.gen.site --site blog --path / --host-dev local.blog.mysite.com --host blog.mysite.com
    mix beacon.gen.site --site shop --path / --host-dev local.shop.mysite.com --host shop.mysite.com
    ```

    To make this work locally, you have two options:

    1. Edit your `/etc/hosts` file (or equivalent) to add:
       ```
       127.0.0.1 local.blog.mysite.com
       127.0.0.1 local.shop.mysite.com
       ```

       This is the simplest solution and works well for local development. Locally in the dev environment, sites would be accessible at:
       - `http://local.blog.mysite.com:4000/`
       - `http://local.shop.mysite.com:4000/`

    2. Use a local development tunneling service. Some options:
       - [ngrok](https://ngrok.com/)
       - [localtunnel](https://localtunnel.github.io/www/)
       - [cloudflare tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/tunnel-guide/local/)

    ## Options

    * `--site` (required) - The name of your site. Should not contain special characters nor start with "beacon_"
    * `--path` (optional) - Where your site will be mounted. Follows the same convention as Phoenix route prefixes. Defaults to `"/"`
    * `--host` (optional) - If provided, site will be served on that host for production environments.
    * `--host-dev` (optional) - If provided, site will be served on that host for dev (local) environments.
    * `--port` (optional) - The port to use for http requests. Only needed when `--host` is provided.  If no port is given, one will be chosen at random.
    * `--secure-port` (optional) - The port to use for https requests. Only needed when `--host` is provided.  If no port is given, one will be chosen at random.
    * `--endpoint` (optional) - The name of the Endpoint Module for your site. If not provided, a default will be generated based on the `site`.
       For example, `beacon.gen.site --site my_site` will use `MySiteEndpoint`
    * `--secret-key-base` (optional) - The value to use for secret_key_base in your app config.
       By default, Beacon will generate a new value and update all existing config to match that value.
       If you don't want this behavior, copy the secret_key_base from your app config and provide it here.
    * `--signing-salt` (optional) - The value to use for signing_salt in your app config.
       By default, Beacon will generate a new value and update all existing config to match that value.
       But in order to avoid connection errors for existing clients, it's recommened to copy the `signing_salt` from your app config and provide it here.
    * `--session-key` (optional) - The value to use for key in the session config. Defaults to `"_your_app_name_key"`
    * `--session-same-site` (optional) - Set the cookie session SameSite attributes. Defaults to "Lax"

    """
  end
end

defmodule Mix.Tasks.Beacon.Gen.Site do
  @shortdoc "#{__MODULE__.Docs.short_doc()}"

  @moduledoc __MODULE__.Docs.long_doc()

  use Mix.Task

  def run(_argv) do
    Mix.shell().error("""
    The task 'beacon.gen.site' is not available.

    Please follow the installation guide at: https://hexdocs.pm/beacon
    """)

    exit({:shutdown, 1})
  end
end
