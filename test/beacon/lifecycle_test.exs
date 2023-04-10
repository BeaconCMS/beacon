defmodule Beacon.LifecycleTest do
  use ExUnit.Case, async: true

  alias Beacon.Lifecycle

  describe "load_template" do
    setup do
      page = %Beacon.Pages.Page{
        site: :test_lifecycle,
        path: "/test/lifecycle",
        format: "custom",
        template: "<div>{ title }</div>"
      }

      [page: page]
    end

    test "load stage", %{page: page} do
      template_formats = [
        {"custom", "custom format",
         load: [
           assigns: fn template, _metadata -> {:cont, String.replace(template, "{ title }", "Beacon")} end,
           downcase: fn template, _metadata -> {:cont, String.downcase(template)} end
         ],
         render: []}
      ]

      assert Lifecycle.do_load_template(page, template_formats) == "<div>beacon</div>"
    end

    test "no format registered", %{page: page} do
      assert_raise Beacon.LoaderError, ~r/expected a template registered for the format.*/, fn ->
        Lifecycle.do_load_template(page, [])
      end
    end

    test "step must return :cont or :halt", %{page: page} do
      template_formats = [{"custom", "custom format", load: [my_step: fn _, _ -> :invalid end], render: []}]

      assert_raise Beacon.LoaderError, ~r/expected step :my_step to return one of the following.*/, fn ->
        assert Lifecycle.do_load_template(page, template_formats)
      end
    end

    test "halt with exception", %{page: page} do
      template_formats = [
        {"custom", "custom format",
         load: [
           my_step: fn _template, _metadata -> {:halt, %RuntimeError{message: "halt"}} end
         ],
         render: []}
      ]

      assert_raise Beacon.LoaderError, ~r/step :my_step halted with the following message.*/, fn ->
        Lifecycle.do_load_template(page, template_formats)
      end
    end

    test "reraise loader error", %{page: page} do
      template_formats = [
        {"custom", "custom format",
         load: [
           my_step: fn _template, _metadata -> raise "fail" end
         ],
         render: []}
      ]

      assert_raise Beacon.LoaderError, ~r/expected stage load to define steps.*/, fn ->
        Lifecycle.do_load_template(page, template_formats)
      end
    end
  end

  describe "render_template" do
    setup do
      opts = [
        site: :test_lifecycle,
        path: "/test/lifecycle",
        format: "custom",
        template: "<div>{ title }</div>",
        assigns: %{},
        env: __ENV__
      ]

      [opts: opts]
    end

    test "template must be valid heex", %{opts: opts} do
      template_formats = [
        {"custom", "custom format",
         load: [],
         render: [
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
         ]}
      ]

      assert %Phoenix.LiveView.Rendered{static: ["<p>Beacon</p>"]} = Lifecycle.do_render_template(opts, template_formats)
    end

    test "render must return a Phoenix.LiveView.Rendered struct", %{opts: opts} do
      template_formats = [
        {"custom", "custom format",
         load: [],
         render: [
           assigns: fn template, _metadata -> {:cont, template} end
         ]}
      ]

      assert_raise Beacon.LoaderError, ~r/expected the stage :render of format custom to return.*/, fn ->
        Lifecycle.do_render_template(opts, template_formats)
      end
    end
  end
end
