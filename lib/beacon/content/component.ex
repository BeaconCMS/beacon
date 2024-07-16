defmodule Beacon.Content.Component do
  @moduledoc """
  Components

  > #### Do not create or edit components manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

  use Beacon.Schema

  alias Beacon.Content
  alias Beacon.Content.ComponentAttr
  alias Beacon.Content.ComponentSlot

  @categories [:html_tag, :data, :element, :media]

  @type t :: %__MODULE__{}

  schema "beacon_components" do
    field :site, Beacon.Types.Site
    field :name, :string
    field :description, :string
    field :body, :string
    field :template, :string
    field :example, :string
    field :category, Ecto.Enum, values: @categories, default: :element
    field :thumbnail, :string

    has_many :attrs, ComponentAttr, on_replace: :delete
    has_many :slots, ComponentSlot, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    reserved_names = for {name, _arity} <- Phoenix.Component.__info__(:functions) ++ Phoenix.Component.__info__(:macros), do: Atom.to_string(name)

    component
    |> cast(attrs, [:site, :name, :description, :body, :template, :example, :category, :thumbnail])
    |> validate_required([:site, :name, :template, :example, :category])
    |> validate_format(:name, ~r/^[a-z0-9_!]+$/, message: "can only contain lowercase letters, numbers, and underscores")
    |> validate_exclusion(:name, reserved_names)
    |> validate_unique_attr_name(attrs)
    |> cast_assoc(:attrs, with: &ComponentAttr.changeset/2)
    |> cast_assoc(:slots, with: &ComponentSlot.changeset/2)
  end

  defp validate_unique_attr_name(changeset, attrs) do
    component_attrs = attrs["attrs"] || []

    attr_names =
      Enum.map(component_attrs, fn
        %{name: name} -> name
        {_index, attr} -> attr["name"]
      end)

    if Enum.uniq(attr_names) == attr_names do
      changeset
    else
      add_error(changeset, :attrs, "component attribute list contains duplicate names")
    end
  end

  def categories, do: @categories

  @doc false
  def validate_if_struct_name_required(changeset) do
    type = get_field(changeset, :type)
    struct_name = get_field(changeset, :struct_name)

    if type == "struct" and is_nil(struct_name) do
      add_error(changeset, :struct_name, "is required when type is 'struct'")
    else
      changeset
    end
  end

  @doc false
  def validate_struct_name(changeset) do
    struct_name = get_field(changeset, :struct_name)

    if struct_name do
      loaded = [struct_name] |> Module.concat() |> :erlang.module_loaded()

      if loaded do
        changeset
      else
        add_error(changeset, :struct_name, "the struct #{struct_name} is undefined")
      end
    else
      changeset
    end
  end

  @doc false
  def validate_non_empty_examples_opts(changeset) do
    opts = get_field(changeset, :opts) |> maybe_binary_to_term()

    if :examples in Keyword.keys(opts) do
      case Keyword.get(opts, :examples) do
        [_ | _] -> changeset
        _ -> add_error(changeset, :opts_examples, "if provided, examples must be a non-empty list")
      end
    else
      changeset
    end
  end

  @doc false
  def validate_non_empty_values_opts(changeset) do
    opts = get_field(changeset, :opts) |> maybe_binary_to_term()

    if :values in Keyword.keys(opts) do
      case Keyword.get(opts, :values) do
        [_ | _] -> changeset
        _ -> add_error(changeset, :opts_values, "if provided, :values must be a non-empty list")
      end
    else
      changeset
    end
  end

  @doc false
  def validate_equivalent_options(changeset) do
    opts = get_field(changeset, :opts) |> maybe_binary_to_term()
    required_opts = get_field_from_opts(changeset, :required)

    values_opts = get_field_from_opts(changeset, :values)
    examples_opts = get_field_from_opts(changeset, :examples)

    cond do
      not is_nil(required_opts) and :default in Keyword.keys(opts) ->
        add_error(changeset, :opts_default, "only one of 'Required' or 'Default' attribute must be given")

      not is_nil(values_opts) and not is_nil(examples_opts) ->
        add_error(changeset, :opts_examples, "only one of 'Accepted values' or 'Examples' must be given")

      true ->
        changeset
    end
  end

  @doc false
  def validate_default_opts_is_in_values_opts(%Changeset{valid?: false} = changeset), do: changeset

  def validate_default_opts_is_in_values_opts(%Changeset{valid?: true} = changeset) do
    opts = get_field(changeset, :opts) |> maybe_binary_to_term()
    values_opts = get_field_from_opts(changeset, :values)
    default_opts = get_field_from_opts(changeset, :default)

    cond do
      :default not in Keyword.keys(opts) or is_nil(values_opts) -> changeset
      default_opts in values_opts -> changeset
      true -> add_error(changeset, :opts_default, "expected the default value to be one of the Accepted Values list")
    end
  end

  @doc false
  def validate_type_and_default_opts(changeset) do
    type = get_field(changeset, :type)
    default_opts = get_field_from_opts(changeset, :default)

    Content.validate_if_value_matches_type(changeset, type, default_opts, :opts_default)
  end

  @doc false
  def validate_struct_name_and_default_opts(%Changeset{valid?: false} = changeset), do: changeset

  def validate_struct_name_and_default_opts(%Changeset{valid?: true} = changeset) do
    struct_name = get_field(changeset, :struct_name)
    default_opts = get_field_from_opts(changeset, :default)

    if is_nil(struct_name) or is_nil(default_opts) do
      changeset
    else
      struct = Module.concat([struct_name])

      case struct(struct) == default_opts do
        true -> changeset
        _ -> add_error(changeset, :opts_default, "expected the default value to be a #{struct_name} struct")
      end
    end
  end

  @doc false
  def validate_type_and_examples_opts(%Changeset{valid?: false} = changeset), do: changeset

  def validate_type_and_examples_opts(%Changeset{valid?: true} = changeset) do
    type = get_field(changeset, :type)
    examples_opts = get_field(changeset, :opts) |> maybe_binary_to_term() |> Keyword.get(:examples, [])

    Enum.reduce(examples_opts, changeset, fn value, changeset -> Content.validate_if_value_matches_type(changeset, type, value, :opts_examples) end)
  end

  @doc false
  def validate_type_and_values_opts(%Changeset{valid?: false} = changeset), do: changeset

  def validate_type_and_values_opts(%Changeset{valid?: true} = changeset) do
    type = get_field(changeset, :type)
    values_opts = get_field(changeset, :opts) |> maybe_binary_to_term() |> Keyword.get(:values, [])

    Enum.reduce(values_opts, changeset, fn value, changeset -> Content.validate_if_value_matches_type(changeset, type, value, :opts_values) end)
  end

  defp get_field_from_opts(changeset, field) do
    get_field(changeset, :opts) |> maybe_binary_to_term() |> Keyword.get(field)
  end

  defp maybe_binary_to_term(opts) when is_binary(opts), do: :erlang.binary_to_term(opts)
  defp maybe_binary_to_term(opts), do: opts
end
