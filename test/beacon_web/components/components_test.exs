defmodule BeaconWeb.ComponentsTest do
  use BeaconWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest
  import Beacon.Fixtures

  alias Beacon.Content

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    :ok
  end

  describe "image" do
    setup context do
      create_page_with_component("""
      <main>
        <p>
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut eget magna et ex accumsan tempus. Duis scelerisque vitae augue sed egestas. Nunc euismod lectus neque, eget vestibulum dolor iaculis convallis. Suspendisse suscipit justo tortor, et sollicitudin nulla ullamcorper eget. Nunc semper ac mauris ac iaculis. Quisque ac ligula id justo volutpat suscipit vitae nec lacus. Suspendisse fringilla, tellus at gravida convallis, magna lacus facilisis ex, ut convallis lacus nulla fringilla purus.
        </p>

        <p>
      Sed a aliquam lorem. Fusce pulvinar sapien sit amet tempus molestie. Sed luctus felis a augue iaculis porttitor. Vestibulum lobortis auctor nisi, et eleifend lorem tempus at. Praesent at massa quis ipsum viverra tristique. Suspendisse consectetur sodales feugiat. Nunc fermentum felis sem, eget vestibulum elit pulvinar vel. Nam a leo eu metus mattis pretium a ac ex. Sed tincidunt, tellus at commodo bibendum, enim orci rhoncus risus, vel sollicitudin velit nisi nec nunc. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos.
        </p>

        <p>
      Morbi id velit sollicitudin, porta risus et, malesuada turpis. Phasellus sodales est eget quam dignissim, vel consectetur eros pellentesque. Morbi vulputate tellus eu pellentesque eleifend. Quisque vitae nibh erat. Sed sit amet consectetur nulla. Duis gravida magna eget nisl pharetra, sed laoreet diam molestie. Cras suscipit placerat nulla quis rhoncus.
        </p>

        <p>
      Aenean blandit tempor eleifend. Donec vitae sapien vel massa fermentum feugiat a sit amet lectus. Integer sapien nibh, ullamcorper in mauris sit amet, accumsan pulvinar felis. Nulla facilisi. Mauris rhoncus vulputate leo eget accumsan. Aliquam erat volutpat. In sed nisl ac nisi dapibus suscipit. Sed pulvinar nisl vel arcu vulputate, vel auctor ex condimentum. Curabitur in tincidunt ex, sed tincidunt est. Sed non orci mattis, luctus nisl et, tincidunt mauris. Nunc finibus arcu.
        </p>
        <BeaconWeb.Components.reading_time />
      </main>
      """)

      context
    end

    test "SUCCESS: reading_time should show 1 min to read the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/home")

      assert render(view) =~ "1"
    end
  end

  defp create_page_with_component(template) do
    layout = published_layout_fixture()

    published_page_fixture(
      layout_id: layout.id,
      path: "home",
      template: template
    )

    Beacon.Loader.load_components(:my_site)
    Beacon.Loader.load_pages(:my_site)
  end
end
