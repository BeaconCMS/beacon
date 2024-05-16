defmodule Beacon.Content.PageFieldTest do
  use Beacon.DataCase, async: true

  import Beacon.Fixtures
  alias Beacon.Content.PageField

  @form %Phoenix.HTML.Form{}

  defmodule BeaconTest.PageFieldTags do
    use Phoenix.Component
    import BeaconWeb.CoreComponents
    import Ecto.Changeset

    @behaviour Beacon.Content.PageField

    @impl true
    def name, do: :tags

    @impl true
    def type, do: :string

    @impl true
    def default, do: "beacon,test"

    @impl true
    def render(assigns) do
      ~H"""
      <.input type="text" label="Tags" field={@field} />
      """
    end

    @impl true
    def changeset(data, attrs, _metadata) do
      data
      |> cast(attrs, [:tags])
      |> validate_format(:tags, ~r/,/, message: "invalid format")
    end
  end

  describe "apply_changesets" do
    setup do
      page = page_fixture()
      page_changeset = Beacon.Content.change_page(page)
      [page_changeset: page_changeset]
    end

    test "empty params", %{page_changeset: page_changeset} do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{extra: %{"tags" => nil}},
               errors: []
             } = PageField.do_apply_changesets([BeaconTest.PageFieldTags], page_changeset, %{})

      assert %Ecto.Changeset{
               valid?: true,
               changes: %{extra: %{"tags" => nil}},
               errors: []
             } = PageField.do_apply_changesets([BeaconTest.PageFieldTags], page_changeset, nil)
    end

    test "invalid params", %{page_changeset: page_changeset} do
      assert %Ecto.Changeset{
               valid?: false,
               changes: %{extra: %{"tags" => "foo"}},
               errors: [extra: {"invalid", [tags: {"invalid format", [validation: :format]}]}]
             } = PageField.do_apply_changesets([BeaconTest.PageFieldTags], page_changeset, %{"tags" => "foo"})
    end

    test "valid params", %{page_changeset: page_changeset} do
      assert %Ecto.Changeset{
               valid?: true,
               changes: %{extra: %{"tags" => "foo,bar"}},
               errors: []
             } = PageField.do_apply_changesets([BeaconTest.PageFieldTags], page_changeset, %{"tags" => "foo,bar"})
    end
  end

  describe "extra_fields" do
    setup do
      page = page_fixture()
      page_changeset = Beacon.Content.change_page(page)
      [page_changeset: page_changeset]
    end

    test "build form field" do
      assert %{
               tags: %Phoenix.HTML.FormField{
                 id: "page-form_extra_tags",
                 name: "page[extra][tags]",
                 errors: [],
                 field: :tags,
                 value: "foo,bar"
               }
             } = PageField.do_extra_fields([BeaconTest.PageFieldTags], @form, %{"tags" => "foo,bar"}, [])
    end

    test "default value" do
      assert %{
               tags: %Phoenix.HTML.FormField{value: "beacon,test"}
             } = PageField.do_extra_fields([BeaconTest.PageFieldTags], @form, %{}, [])
    end

    test "errors", %{page_changeset: page_changeset} do
      page_changeset = PageField.do_apply_changesets([BeaconTest.PageFieldTags], page_changeset, %{"tags" => "foo"})

      assert %{
               tags: %Phoenix.HTML.FormField{
                 value: "foo",
                 errors: [{"invalid format", [validation: :format]}]
               }
             } = PageField.do_extra_fields([BeaconTest.PageFieldTags], @form, %{"tags" => "foo"}, page_changeset.errors)
    end
  end

  test "traverse_errors" do
    assert PageField.traverse_errors(
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
