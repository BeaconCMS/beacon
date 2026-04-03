defmodule Mix.Tasks.Beacon.Gen.TailwindConfig.Docs do
  @moduledoc false

  def short_doc do
    "Generates a new Tailwind config in the format expected by Beacon"
  end

  def example do
    "mix beacon.gen.tailwind_config"
  end

  def long_doc do
    """
    #{short_doc()}

    It will also update your Phoenix project configuration to bundle the Tailwind configuration.

    See https://hexdocs.pm/beacon/tailwind-setup.html for more info.

    ## Example

    ```bash
    #{example()}
    ```

    """
  end
end

defmodule Mix.Tasks.Beacon.Gen.TailwindConfig do
  @shortdoc "#{__MODULE__.Docs.short_doc()}"

  @moduledoc __MODULE__.Docs.long_doc()

  use Mix.Task

  def run(_argv) do
    Mix.shell().error("""
    The task 'beacon.gen.tailwind_config' is not available.

    Please follow the installation guide at: https://hexdocs.pm/beacon
    """)

    exit({:shutdown, 1})
  end
end
