defmodule Beacon.Lifecycle.PageTest do
  use ExUnit.Case, async: true

  alias Beacon.Lifecycle

  test "publish_page" do
    page = %{site: :lifecycle_test}
    assert %Beacon.Pages.Page{status: :published} = Lifecycle.Page.publish_page(page)
  end

  test "create_page" do
    page = %{site: :lifecycle_test}
    assert %Beacon.Pages.Page{template: "<h1>Created</h1>"} = Lifecycle.Page.create_page(page)
  end

  test "update_page" do
    page = %{site: :lifecycle_test}
    assert %Beacon.Pages.Page{template: "<h1>Updated</h1>"} = Lifecycle.Page.update_page(page)
  end
end
