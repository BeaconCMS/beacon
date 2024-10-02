defmodule Beacon.Test do
  @moduledoc """
  Testing utilities to create and assert Beacon resources.

  ## Usage

  First you need to activate the `:manual` mode in your site configuration:

  ```elixir
  # test.exs
  # active manual mode for all sites under test
  config :my_app, Beacon, sites: [[site: :my_site, mode: :manual]]
  ```

  See `Beacon.start_link/1` for more info on how to setup your Beacon configuration.

  Then use this module either in your test module or in your test case template:

  ```elixir
  defmodule MyAppWeb.CMSTest do
    use MyAppWeb.ConnCase
    use Beacon.Test
    # ...
  end
  ```

  or make it available for all your tests by adding it to your test case template:

  ```elixir
  defmodule MyAppWeb.ConnCase do
    use ExUnit.CaseTemplate

    using do
      quote do
        use Beacon.Test
        # ...
      end
    end
  end
  ```

  With this configuration, Beacon will perform some operations so the environment is better suited for testing:

  - Do not hot-load resources during boot
  - Do not broadcast events on Content changes
  - Perform most operations in a synchronous way

  And all functions in `Beacon.Test.Fixtures` will be imported to help you create resources in your tests.

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Beacon.Test.Fixtures
    end
  end
end
