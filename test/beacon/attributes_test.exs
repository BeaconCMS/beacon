defmodule Beacon.MetatagsTest do
  use Beacon.DataCase

  alias Beacon.Types.Tag

  defp page_and_layout_attributes(usage) do
    case usage do
      :input ->
        [
          [{"something", "else"}, {"content", "value"}, {"property", "test"}, {"something", "else"}],
          [{"something", "else"}, {"content", "value"}, {"something", "else"}, {"name", "test"}]
        ]

      :expected ->
        [
          [{"property", "test"}, {"content", "value"}, {"something", "else"}, {"something", "else"}],
          [{"name", "test"}, {"content", "value"}, {"something", "else"}, {"something", "else"}]
        ]
    end
  end

  defp site_attributes(usage) do
    case usage do
      :input ->
        [
          [{"something", "else"}, {"charset", "utf-8"}, {"something", "else"}],
          [{"something", "else"}, {"content", "IE=edge"}, {"something", "else"}, {"http-equiv", "X-UA-Compatible"}],
          [{"something", "else"}, {"content", "width=device-width, initial-scale=1"}, {"name", "viewport"}, {"something", "else"}],
          [{"something", "else"}, {"name", "csrf-token"}, {"something", "else"}]
        ]

      :expected ->
        [
          [{"charset", "utf-8"}, {"something", "else"}, {"something", "else"}],
          [{"http-equiv", "X-UA-Compatible"}, {"content", "IE=edge"}, {"something", "else"}, {"something", "else"}],
          [{"name", "viewport"}, {"content", "width=device-width, initial-scale=1"}, {"something", "else"}, {"something", "else"}],
          [{"name", "csrf-token"}, {"something", "else"}, {"something", "else"}]
        ]
    end
  end

  describe "order attributes" do
    test "for the page/layout" do
      assert Tag.order_attributes(page_and_layout_attributes(:input)) == page_and_layout_attributes(:expected)
    end

    test "for the site" do
      assert Beacon.order_attributes(site_attributes(:input)) == site_attributes(:expected)
    end
  end
end
