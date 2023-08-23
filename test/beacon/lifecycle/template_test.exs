defmodule Beacon.Lifecycle.TemplateTest do
  use Beacon.DataCase, async: false

  import Beacon.Fixtures
  alias Beacon.Lifecycle

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  test "load_template" do
    page = %Beacon.Content.Page{
      site: :lifecycle_test,
      path: "/test/lifecycle",
      format: :markdown,
      template: "<div>{ title }</div>"
    }

    assert Lifecycle.Template.load_template(page) == "<div>beacon</div>"
  end

  test "render_template" do
    page = page_fixture(site: "my_site") |> Repo.preload([:event_handlers, :variants])
    {:ok, page_module, _ast} = Beacon.Loader.PageModuleLoader.load_page!(page)
    env = BeaconWeb.PageLive.make_env()

    assert %Phoenix.LiveView.Rendered{static: ["<main>\n  <h1>my_site#home</h1>\n</main>"]} =
             Lifecycle.Template.render_template(page, page_module, %{}, env)
  end
end
