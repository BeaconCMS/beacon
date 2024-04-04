defmodule Beacon.MediaLibrary.AssetField do
  @moduledoc ~S"""
  Custom asset fields for assets.

  Each `Beacon.MediaLibrary.Asset` has a default set of fields that
  fits most cases for assets for your sites,
  but in some cases you need custom data to either help manage
  those assets in Beacon Admin or to display such data.

  Each asset field will be:

    * stored in the `asset.extra` map field
    * displayed in Beacon Admin
    * validated when the assets are saved or published

  ## Example

      defmodule MyApp.AltTextField do
        use Phoenix.Component
        import BeaconWeb.CoreComponents
        import Ecto.Changeset

        @behaviour Beacon.MediaLibrary.AssetField

        @impl true
        def name, do: :alt

        @impl true
        def type, do: :string

        @impl true
        def render_input(assigns) do
          ~H\"""
          <.input type="text" label="Alt Text" field={@field} />
          \"""
        end

        @impl true
        def render_show(assigns) do
          ~H\"""
          <.input type="text" label="Alt Text" value={@value} />
          \"""
        end

        @impl true
        def changeset(data, attrs) do
          data
          |> cast(attrs, [:alt])
          |> validate_required([:alt])
        end
      end

  """

  @optional_callbacks default: 0

  @doc """
  Field identifier. Must be unique per site.
  """
  @callback name :: atom()

  @doc """
  Field type. Can be any value supported by Ecto Schema.
  """
  @callback type :: any()

  @doc """
  Default value for field. Defaults to `nil`.
  """
  @callback default :: any()

  @doc """
  Template to render the form field on Admin.
  """
  @callback render_input(assigns :: Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Template to render the show field on Admin.
  """
  @callback render_show(assigns :: Phoenix.LiveView.Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Changeset used to validate and save data.
  """
  @callback changeset(
              data :: {Ecto.Changeset.data(), Ecto.Changeset.types()},
              attrs :: %{String.t() => any()},
              metadata :: %{asset_changeset: Ecto.Changeset.t()}
            ) :: Ecto.Changeset.t()

  @doc false
  def extra_input_fields(site, %Phoenix.HTML.Form{} = form, params, errors) when is_map(params) and is_list(errors) do
    field_configs = Beacon.Config.fetch!(site).extra_asset_fields
    media_type = get_media_type_from_form(form)
    mods = get_extra_fields_for_media_type(field_configs, media_type)
    do_extra_input_fields(mods, form, params, errors)
  end

  defp get_media_type_from_form(%{data: %{"media_type" => media_type}}), do: media_type
  defp get_media_type_from_form(%{data: %{media_type: media_type}}), do: media_type

  def get_extra_fields_for_media_type(field_configs, media_type) do
    case Beacon.Config.get_media_type_config(field_configs, media_type) do
      nil -> []
      {_, mods} -> mods
    end
  end

  @doc false
  def do_extra_input_fields(mods, form, params, errors) do
    errors = traverse_errors(errors)

    Enum.reduce(mods, %{}, fn mod, acc ->
      name = mod.name()
      default = if Beacon.exported?(mod, :default, 0), do: mod.default(), else: nil
      value = Map.get(params, "#{name}", default)
      errors = Map.get(errors, name, [])

      Map.put(acc, name, %Phoenix.HTML.FormField{
        id: "asset_extra_#{name}",
        name: "asset[extra][#{name}]",
        errors: errors,
        field: name,
        value: value,
        form: form
      })
    end)
  end

  @doc false
  def extra_show_fields(asset) do
    field_configs = Beacon.Config.fetch!(asset.site).extra_asset_fields
    get_extra_fields_for_media_type(field_configs, asset.media_type)
  end

  @doc false
  def traverse_errors(errors) when is_list(errors) do
    merge_fields = fn fields ->
      Enum.reduce(fields, %{}, fn {field, error}, acc ->
        Map.update(acc, field, [error], fn e ->
          [error | e]
        end)
      end)
    end

    Enum.reduce(errors, %{}, fn
      {:extra, {_msg, fields}}, acc ->
        field = fields |> merge_fields.() |> Map.new(fn {k, v} -> {k, Enum.reverse(v)} end)
        Map.merge(acc, field)

      _, acc ->
        acc
    end)
  end

  @doc false
  def apply_changesets(%Ecto.Changeset{} = asset_changeset, %{site: site, extra: params} = _metadata) when is_atom(site) and is_nil(params) do
    asset_changeset
  end

  def apply_changesets(%Ecto.Changeset{} = asset_changeset, %{site: site} = metadata) when is_atom(site) do
    field_configs = Beacon.Config.fetch!(metadata.site).extra_asset_fields
    mods = get_extra_fields_for_media_type(field_configs, metadata.media_type)
    do_apply_changesets(mods, asset_changeset, metadata.extra)
  end

  @doc false
  def do_apply_changesets(mods, asset_changeset, params) do
    params = params || %{}

    Enum.reduce(mods, asset_changeset, fn mod, asset_changeset ->
      name = mod.name()
      params = Map.take(params, ["#{name}"])

      type = mod.type()
      types = %{name => type}
      data = {%{}, types}

      field_changeset = mod.changeset(data, params, %{asset_changeset: asset_changeset})

      case Ecto.Changeset.apply_action(field_changeset, :update) do
        {:ok, field} ->
          value = Map.get(field, name)
          extra = Ecto.Changeset.get_field(asset_changeset, :extra) || %{}
          extra = Map.put(extra, "#{name}", value)
          Ecto.Changeset.put_change(asset_changeset, :extra, extra)

        {:error, field_changeset} ->
          value = Ecto.Changeset.apply_changes(field_changeset) |> Map.get(name)
          extra = Ecto.Changeset.get_field(asset_changeset, :extra) || %{}
          extra = Map.put(extra, "#{name}", value)
          asset_changeset = Ecto.Changeset.put_change(asset_changeset, :extra, extra)
          Ecto.Changeset.add_error(asset_changeset, :extra, "invalid", field_changeset.errors)
      end
    end)
  end
end
