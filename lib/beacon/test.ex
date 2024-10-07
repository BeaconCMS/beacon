defmodule Beacon.Test do
  @moduledoc """
  Testing utilities to create and assert Beacon resources.

  ## Usage

  First you need to activate the `:testing` mode in your site configuration:

  ```elixir
  # test.exs
  # active testing mode for all sites under test
  config :my_app, :my_site, mode: :testing
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

  With this configuration, Beacon will behave in a way that is better suited for testing:

  - Do not hot-load resources during boot
  - Do not broadcast events on Content changes
  - Perform most operations in a synchronous way
  - Reload module as fixture data is created

  And all functions in `Beacon.Test.Fixtures` will be imported to help you create resources in your tests.

  ## Default site

  Most of the functions need a `site` option to know which site to operate on.
  If you don't provide it, the default site `:my_site` is used:

  ```elixir
  create_page_fixture(title: "Home")
  %Beacon.Content.Page{site: :my_site, title: "Home"}
  ```

  Or you can override it:

  ```elixir
  create_page_fixture(site: :blog, title: "Home")
  %Beacon.Content.Page{site: :blog, title: "Home"}
  ```

  But doing so every time is not efficient, so you can set a default site that will be used in all function calls:

  ```elixir
  use Beacon.Test, site: :blog

  create_page_fixture(title: "Home")
  %Beacon.Content.Page{site: :blog, title: "Home"}
  ```

  """

  @doc false
  defmacro __using__(opts) do
    site = Keyword.get(opts, :site, :my_site)

    quote do
      use Beacon.Test.Fixtures, site: unquote(site)
    end
  end

  @doc """
  Returns the site defined in the current test.

  Default is `:my_site` if the option `:site` was not set in `use Beacon.Test`
  """
  @spec default_site() :: atom
  def default_site, do: :my_site
end
