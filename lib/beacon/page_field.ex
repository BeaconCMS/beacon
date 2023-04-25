defmodule Beacon.PageField do
  @moduledoc ~S"""
  Add extra fields to pages.

  ## Example

      defmodule MyApp.TagsField do
        use Phoenix.Component
        import BeaconWeb.CoreComponents
        import Ecto.Changeset

        @behaviour Beacon.PageField

        @impl true
        def name, do: :tags

        @impl true
        def type, do: :string

        @impl true
        def render(assigns) do
          ~H\"""
          <.input type="text" label="Tags" field={@field} />
          \"""
        end

        @impl true
        def changeset(data, attrs) do
          data
          |> cast(attrs, [:tags])
          |> validate_required([:tags])
        end
      end

  """

  @doc """
  Field identifier. Must be unique per site.
  """
  @callback name :: atom()

  @doc """
  Field type. Can be any value supported by Ecto Schema.
  """
  @callback type :: any()

  @doc """
  Template to render the field on Admin.
  """
  @callback render(assigns :: Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Changeset used to validate and save data.
  """
  @callback changeset(data :: {Ecto.Changeset.data(), Ecto.Changeset.types()}, attrs :: %{String.t() => any()}) :: Ecto.Changeset.t()

  @doc false
  def extra_fields(site, form, extra, errors) do
    mods = Beacon.Config.fetch!(site).extra_page_fields

    Enum.reduce(mods, %{}, fn mod, acc ->
      name = mod.name()
      value = Map.get(extra, "#{name}")

      errors =
        case errors do
          {_, fields} -> fields
          _ -> []
        end
        |> Keyword.get(name, [])
        |> List.wrap()

      Map.put(acc, name, %Phoenix.HTML.FormField{
        id: "page_extra_#{name}",
        name: "page[extra][#{name}]",
        errors: errors,
        field: name,
        value: value,
        form: form
      })
    end)
  end

  @doc false
  def apply_changesets(page_changeset, site, params) do
    mods = Beacon.Config.fetch!(site).extra_page_fields

    Enum.reduce(mods, page_changeset, fn mod, page_changeset ->
      name = mod.name()
      params = Map.take(params, ["#{name}"])

      type = mod.type()
      types = %{name => type}
      data = {%{}, types}

      field_changeset = mod.changeset(data, params)

      case Ecto.Changeset.apply_action(field_changeset, :update) do
        {:ok, field} ->
          extra = Ecto.Changeset.get_field(page_changeset, :extra) || %{}
          value = Map.get(field, name)
          extra = Map.put(extra, "#{name}", value)
          Ecto.Changeset.put_change(page_changeset, :extra, extra)

        {:error, field_changeset} ->
          Ecto.Changeset.add_error(page_changeset, :extra, "invalid", field_changeset.errors)
      end
    end)
  end
end
