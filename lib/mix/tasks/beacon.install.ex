defmodule Mix.Tasks.Beacon.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs Beacon in a Phoenix LiveView app."
  end

  def example do
    "mix beacon.install"
  end

  def long_doc do
    """
    #{short_doc()}

    It will add the necessary dependencies and configuration into your Phoenix LiveView app.

    The options `--site` and `--path` are optional but you can bootstrap a new site by providing them,
    otherwise execute [`mix beacon.gen.site`](https://hexdocs.pm/beacon/Mix.Tasks.Beacon.Gen.Site.html) at anytime to generate new sites.

    You might want to install [Beacon LiveAdmin](https://hexdocs.pm/beacon_live_admin/Mix.Tasks.Beacon.LiveAdmin.Install.html)
    as well to manage the content of your sites.

    ## Examples

    ```bash
    #{example()}
    ```

    ```bash
    mix beacon.install --site my_site --path /
    ```

    ## Options

    * `--site` (optional) - The name of your site. Should not contain special characters nor start with `"beacon_"`.
    * `--path` (optional, defaults to `"/"`) - Where your site will be mounted. Follows the same convention as Phoenix route prefixes.

    """
  end
end

defmodule Mix.Tasks.Beacon.Install do
  @shortdoc "#{__MODULE__.Docs.short_doc()}"

  @moduledoc __MODULE__.Docs.long_doc()

  use Mix.Task

  def run(_argv) do
    Mix.shell().error("""
    The task 'beacon.install' is not available.

    Please follow the installation guide at: https://hexdocs.pm/beacon
    """)

    exit({:shutdown, 1})
  end
end
