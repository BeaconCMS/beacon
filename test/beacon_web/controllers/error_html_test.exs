defmodule BeaconWeb.ErrorHTMLTest do
  use ExUnit.Case, async: true

  alias BeaconWeb.ErrorHTML

  test "invalid status code" do
    assert ErrorHTML.render("invalid", %{conn: nil}) == "Internal Server Error"
  end

  test "invalid conn" do
    assert ErrorHTML.render("404.html", %{conn: nil}) == "Not Found"
  end
end
