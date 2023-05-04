defmodule Beacon.Lifecycle.TemplateTest do
  use ExUnit.Case, async: true

  alias Beacon.Lifecycle

  describe "load_template" do
    setup do
      page = %Beacon.Pages.Page{
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

  describe "render_template" do
    setup do
      opts = [
        path: "/test/lifecycle",
        assigns: %{},
        env: __ENV__
      ]

      [opts: opts, format: :markdown, template: "<div>{ title }</div>"]
    end

    test "template must be valid heex", %{template: template, format: format, opts: opts} do
      assert %Phoenix.LiveView.Rendered{static: ["<p>Beacon</p>"]} = Lifecycle.Template.render_template(:lifecycle_test, template, format, opts)
    end

    test "render must return a Phoenix.LiveView.Rendered struct", %{template: template, format: format, opts: opts} do
      assert_raise Beacon.LoaderError, ~r/expected the stage render_template of format markdown to return.*/, fn ->
        Lifecycle.Template.render_template(:lifecycle_test_fail, template, format, opts)
      end
    end
  end
end
