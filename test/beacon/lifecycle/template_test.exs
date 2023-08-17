defmodule Beacon.Lifecycle.TemplateTest do
  use ExUnit.Case, async: true

  alias Beacon.Lifecycle

  describe "load_template" do
    setup do
      page = %Beacon.Content.Page{
        site: :lifecycle_test,
        path: "/test/lifecycle",
        format: :markdown,
        template: "<div>{ title }</div>"
      }

      [page: page]
    end

    test "load stage", %{page: page} do
      assert Lifecycle.Template.load_template(page) == "<div>beacon</div>"
    end
  end
end
