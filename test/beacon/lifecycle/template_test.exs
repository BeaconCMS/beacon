defmodule Beacon.Lifecycle.TemplateTest do
  use Beacon.DataCase, async: false

  use Beacon.Test
  alias Beacon.Lifecycle

  setup do
    site = default_site()

    # we aren't passing through PageLive normally in these tests so we have to manually
    # enable the ErrorHandler and set the site in the Process dictionary
    # (which would normally happen in the LiveView mount)
    Process.put(:__beacon_site__, site)
    Process.flag(:error_handler, Beacon.ErrorHandler)

    [site: site]
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

  test "render_template", %{site: site} do
    page = beacon_published_page_fixture(site: site) |> Repo.preload(:variants)
    env = Beacon.Web.PageLive.make_env(site)
    assert %Phoenix.LiveView.Rendered{static: ["<main>\n  <h1>my_site#home</h1>\n</main>"]} = Lifecycle.Template.render_template(page, %{}, env)
  end
end
