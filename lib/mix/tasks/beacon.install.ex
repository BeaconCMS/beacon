defmodule Mix.Tasks.Beacon.Install do
  use Igniter.Mix.Task

  @example "mix beacon.install --example arg"

  @shortdoc "A short description of your task"
  @moduledoc """
  #{@shortdoc}

  Longer explanation of your task

  ## Example

  ```bash
  #{@example}
  ```

  ## Options

  * `--example-option` or `-e` - Docs for your option
  """

  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      # dependencies to add
      adds_deps: [],
      # dependencies to add and call their associated installers, if they exist
      installs: [],
      # An example invocation
      example: @example,
      # Accept additional arguments that are not in your schema
      # Does not guarantee that, when composed, the only options you get are the ones you define
      extra_args?: false,
      # A list of environments that this should be installed in, only relevant if this is an installer.
      only: nil,
      # a list of positional arguments, i.e `[:file]`
      positional: [],
      # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
      # This ensures your option schema includes options from nested tasks
      composes: [],
      # `OptionParser` schema
      schema: [],
      # CLI aliases
      aliases: []
    }
  end

  def igniter(igniter, argv) do
    # extract positional arguments according to `positional` above
    {arguments, argv} = positional_args!(argv)
    # extract options according to `schema` and `aliases` above
    options = options!(argv)

    # Do your work here and return an updated igniter
    igniter
    |> Igniter.Project.Formatter.import_dep(:beacon)
  end
end
