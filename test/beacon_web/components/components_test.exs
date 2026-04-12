defmodule Beacon.Web.ComponentsTest do
  use Beacon.Web.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  use Beacon.Test

  # These tests used Phoenix function components (<.reading_time>, <.embedded>,
  # <.featured_pages>) which are HEEx-specific. In the platform-agnostic template
  # system, these would be Beacon components with their functionality moved to
  # the data layer (GraphQL resolvers) or implemented as built-in AST components.
  #
  # Skipped until Beacon components are implemented for these use cases.

  @tag :skip
  test "placeholder" do
    assert true
  end
end
