defmodule Beacon.LifecycleTest do
  use ExUnit.Case, async: true

  alias Beacon.Lifecycle

  describe "load_template" do
    setup do
      page = %Beacon.Pages.Page{
        site: :test_lifecycle,
        path: "/test/lifecycle",
        format: :test,
        template: "<div>{ title }</div>"
      }

      [page: page]
    end

    test "load stage", %{page: page} do
      steps = [
        assigns: fn template, _metadata -> {:cont, String.replace(template, "{ title }", "Beacon")} end,
        downcase: fn template, _metadata -> {:cont, String.downcase(template)} end
      ]

      assert Lifecycle.do_load_template(page, steps) == "<div>beacon</div>"
    end

    test "step must return :cont or :halt", %{page: page} do
      steps = [my_step: fn _, _ -> :invalid end]

      assert_raise Beacon.LoaderError, ~r/expected step :my_step to return one of the following.*/, fn ->
        assert Lifecycle.do_load_template(page, steps)
      end
    end

    test "halt with exception", %{page: page} do
      steps = [my_step: fn _template, _metadata -> {:halt, %RuntimeError{message: "halt"}} end]

      assert_raise Beacon.LoaderError, ~r/step :my_step halted with the following message.*/, fn ->
        Lifecycle.do_load_template(page, steps)
      end
    end

    test "reraise loader error", %{page: page} do
      steps = [my_step: fn _template, _metadata -> raise "fail" end]

      assert_raise Beacon.LoaderError, ~r/expected stage load_template to define steps.*/, fn ->
        Lifecycle.do_load_template(page, steps)
      end
    end
  end

  describe "render_template" do
    setup do
      opts = [
        site: :test_lifecycle,
        path: "/test/lifecycle",
        format: :test,
        template: "<div>{ title }</div>",
        assigns: %{},
        env: __ENV__
      ]

      [opts: opts]
    end

    test "template must be valid heex", %{opts: opts} do
      steps = [
        div_to_p: fn template, _metadata -> {:cont, String.replace(template, "div", "p")} end,
        assigns: fn template, _metadata -> {:cont, String.replace(template, "{ title }", "Beacon")} end,
        compile: fn template, _metadata ->
          ast = Beacon.Template.HEEx.compile_heex_template!("nofile", template)
          {:cont, ast}
        end,
        eval: fn template, _metadata ->
          {rendered, _bindings} = Code.eval_quoted(template, [assigns: %{}], file: "nofile")
          {:halt, rendered}
        end
      ]

      assert %Phoenix.LiveView.Rendered{static: ["<p>Beacon</p>"]} = Lifecycle.do_render_template(opts, steps)
    end

    test "render must return a Phoenix.LiveView.Rendered struct", %{opts: opts} do
      steps = [assigns: fn template, _metadata -> {:cont, template} end]

      assert_raise Beacon.LoaderError, ~r/expected the stage render_template of format test to return.*/, fn ->
        Lifecycle.do_render_template(opts, steps)
      end
    end
  end

  test "publish_page" do
    steps = [
      notify: fn page ->
        page = %{page | custom_field: true}
        send(self(), {:page_published, page})
        {:cont, page}
      end
    ]

    Lifecycle.do_publish_page(%{title: "my page", custom_field: false}, steps)

    assert_receive {:page_published, %{title: "my page", custom_field: true}}
  end
end
