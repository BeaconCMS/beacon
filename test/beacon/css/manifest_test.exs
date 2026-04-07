defmodule Beacon.CSS.ManifestTest do
  use ExUnit.Case, async: true

  alias Beacon.CSS.Manifest

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      attrs = %{
        site: "my_site",
        hash: "abc123def456",
        s3_key: "beacon/css/my_site/abc123def456"
      }

      changeset = Manifest.changeset(%Manifest{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :site) == "my_site"
      assert Ecto.Changeset.get_change(changeset, :hash) == "abc123def456"
      assert Ecto.Changeset.get_change(changeset, :s3_key) == "beacon/css/my_site/abc123def456"
    end

    test "invalid changeset missing site" do
      attrs = %{hash: "abc123", s3_key: "beacon/css/test/abc123"}

      changeset = Manifest.changeset(%Manifest{}, attrs)

      refute changeset.valid?
      assert {:site, _} = hd(changeset.errors)
    end

    test "invalid changeset missing hash" do
      attrs = %{site: "my_site", s3_key: "beacon/css/test/abc123"}

      changeset = Manifest.changeset(%Manifest{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :hash)
    end

    test "invalid changeset missing s3_key" do
      attrs = %{site: "my_site", hash: "abc123"}

      changeset = Manifest.changeset(%Manifest{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :s3_key)
    end

    test "invalid changeset with no fields" do
      changeset = Manifest.changeset(%Manifest{}, %{})

      refute changeset.valid?
    end
  end
end
