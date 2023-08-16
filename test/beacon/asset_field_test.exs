defmodule Beacon.AssetFieldTest do
  use Beacon.DataCase, async: true

  import Beacon.Fixtures
  alias Beacon.MediaLibrary.AssetField
  alias Beacon.MediaLibrary.AssetFields.AltText

  @form %Phoenix.HTML.Form{}

  describe "apply_changesets" do
    setup do
      asset = media_library_asset_fixture()
      asset_changeset = Beacon.MediaLibrary.change_asset(asset)
      [asset_changeset: asset_changeset]
    end

    test "empty params", %{asset_changeset: asset_changeset} do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{extra: %{"alt" => nil}},
               errors: []
             } = AssetField.do_apply_changesets([AltText], asset_changeset, %{})

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{extra: %{"alt" => nil}},
               errors: []
             } = AssetField.do_apply_changesets([AltText], asset_changeset, nil)
    end

    test "valid params", %{asset_changeset: asset_changeset} do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{extra: %{"alt" => "some other alt text"}},
               errors: []
             } = AssetField.do_apply_changesets([AltText], asset_changeset, %{"alt" => "some other alt text"})
    end
  end

  describe "extra_fields" do
    setup do
      asset = media_library_asset_fixture()
      asset_changeset = Beacon.MediaLibrary.change_asset(asset)
      [asset_changeset: asset_changeset]
    end

    test "build form field" do
      assert %{
               alt: %Phoenix.HTML.FormField{
                 id: "asset_extra_alt",
                 name: "asset[extra][alt]",
                 errors: [],
                 field: :alt,
                 value: "some alt text"
               }
             } = AssetField.do_extra_input_fields([AltText], @form, %{"alt" => "some alt text"}, [])
    end
  end

  test "traverse_errors" do
    assert AssetField.traverse_errors(
             extra:
               {"invalid",
                [
                  field_a: {"message_1", [validation: 1]},
                  field_a: {"message_2", [validation: 2]}
                ]},
             extra:
               {"invalid",
                [
                  field_c: {"message_3", [validation: 3]}
                ]}
           ) == %{
             field_a: [{"message_1", [validation: 1]}, {"message_2", [validation: 2]}],
             field_c: [{"message_3", [validation: 3]}]
           }
  end
end
