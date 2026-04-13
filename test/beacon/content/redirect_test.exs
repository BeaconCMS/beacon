defmodule Beacon.Content.RedirectTest do
  use ExUnit.Case, async: true

  alias Beacon.Content.Redirect

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{site: :my_site, source_path: "/old", destination_path: "/new", status_code: 301}
      changeset = Redirect.changeset(%Redirect{}, attrs)
      assert changeset.valid?
    end

    test "requires source_path" do
      attrs = %{site: :my_site, destination_path: "/new", status_code: 301}
      changeset = Redirect.changeset(%Redirect{}, attrs)
      refute changeset.valid?
    end

    test "requires destination_path" do
      attrs = %{site: :my_site, source_path: "/old", status_code: 301}
      changeset = Redirect.changeset(%Redirect{}, attrs)
      refute changeset.valid?
    end

    test "validates status_code inclusion" do
      attrs = %{site: :my_site, source_path: "/old", destination_path: "/new", status_code: 404}
      changeset = Redirect.changeset(%Redirect{}, attrs)
      refute changeset.valid?
    end

    test "accepts valid status codes" do
      for code <- [301, 302, 307, 308] do
        attrs = %{site: :my_site, source_path: "/old", destination_path: "/new", status_code: code}
        changeset = Redirect.changeset(%Redirect{}, attrs)
        assert changeset.valid?, "Expected #{code} to be valid"
      end
    end

    test "rejects self-referencing redirect" do
      attrs = %{site: :my_site, source_path: "/same", destination_path: "/same", status_code: 301}
      changeset = Redirect.changeset(%Redirect{}, attrs)
      refute changeset.valid?
    end

    test "defaults status_code to 301" do
      attrs = %{site: :my_site, source_path: "/old", destination_path: "/new"}
      changeset = Redirect.changeset(%Redirect{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :status_code) == 301
    end

    test "defaults is_regex to false" do
      attrs = %{site: :my_site, source_path: "/old", destination_path: "/new"}
      changeset = Redirect.changeset(%Redirect{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :is_regex) == false
    end
  end
end
