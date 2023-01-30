defmodule Beacon.PagesTest do
  use Beacon.DataCase

  import Beacon.Fixtures
  alias Beacon.Pages
  alias Beacon.Pages.Page

  defp create_page(_) do
    page_fixture()
    :ok
  end

  describe "list_pages/1" do
    setup [:create_page]

    test "list pages" do
      assert [%Page{}] = Pages.list_pages()
    end
  end
end
