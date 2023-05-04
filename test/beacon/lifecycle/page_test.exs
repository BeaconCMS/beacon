defmodule Beacon.Lifecycle.PageTest do
  use ExUnit.Case, async: true

  alias Beacon.Lifecycle

  test "publish_page" do
    page = %{site: :lifecycle_test}
    assert :page_published = Lifecycle.Page.publish_page(page)
  end

  test "create_page" do
    page = %{site: :lifecycle_test}
    assert :page_created = Lifecycle.Page.create_page(page)
  end

  test "update_page" do
    page = %{site: :lifecycle_test}
    assert :page_updated = Lifecycle.Page.update_page(page)
  end
end
