defmodule Beacon.Template.HeexTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.HEEx

  test "render_component" do
    assert HEEx.render_component(~S|<.link patch="/contact" replace={true}><%= @text %></.link>|, %{text: "Book Meeting"}) ==
             ~S|<a href="/contact" data-phx-link="patch" data-phx-link-state="replace">Book Meeting</a>|
  end
end
