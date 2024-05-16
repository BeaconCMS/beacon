defmodule Beacon.Lifecycle.TemplateTest do
  use Beacon.DataCase, async: false

  import Beacon.Fixtures
  alias Beacon.Lifecycle

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
    page = published_page_fixture(site: "my_site") |> Repo.preload([:event_handlers, :variants])
    env = BeaconWeb.PageLive.make_env()

    assert %Phoenix.LiveView.Rendered{static: ["<main>\n  <h1>my_site#home</h1>\n</main>"]} =
             Lifecycle.Template.render_template(page, %{}, env)
  end
end
