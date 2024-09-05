defmodule Beacon.Web.ErrorHTMLTest do
  use ExUnit.Case, async: true

  alias Beacon.Web.ErrorHTML

  @tag capture_log: true
  test "invalid status code" do
    assert ErrorHTML.render("invalid", %{conn: nil}) == "Internal Server Error"
  end

  @tag capture_log: true
  test "invalid conn" do
    assert ErrorHTML.render("404.html", %{conn: nil}) == "Not Found"
  end
end
