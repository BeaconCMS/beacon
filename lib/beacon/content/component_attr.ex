defmodule Beacon.Content.ComponentAttr do
  @moduledoc false

  use Beacon.Schema

  alias Beacon.Content
  alias Beacon.Content.Component
  alias Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "beacon_component_attrs" do
    field :name, :string
    field :type, :string
    field :struct_name, :string
    field :opts, Beacon.Types.Binary, default: []

    belongs_to :component, Component

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:id, :name, :type, :struct_name, :opts, :component_id])
    |> validate_required([:name, :type])
    |> validate_format(:name, ~r/^[a-zA-Z0-9_!?]+$/, message: "can only contain letters, numbers, and underscores")
    |> validate_if_struct_name_required()
    |> validate_non_empty_examples_opts()
    |> validate_non_empty_values_opts()
    |> validate_equivalent_options()
    |> validate_default_opts_is_in_values_opts()
    |> validate_type_and_values_opts()
    |> validate_type_and_default_opts()
    |> validate_type_and_examples_opts()
  end

  def validate_if_struct_name_required(changeset) do
    type = get_field(changeset, :type)
    struct_name = get_field(changeset, :struct_name)

    if type == "struct" and is_nil(struct_name) do
      add_error(changeset, :struct_name, "is required when type is 'struct'")
    else
      changeset
    end
  end

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

  def validate_equivalent_options(changeset) do
    required_opts = get_field_from_opts(changeset, :required)
    default_opts = get_field_from_opts(changeset, :default)

    values_opts = get_field_from_opts(changeset, :values)
    examples_opts = get_field_from_opts(changeset, :examples)

    cond do
      not is_nil(required_opts) and not is_nil(default_opts) ->
        add_error(changeset, :opts_default, "only one of 'Required' or 'Default' attribute must be given")

      not is_nil(values_opts) and not is_nil(examples_opts) ->
        add_error(changeset, :opts_examples, "only one of 'Accepted values' or 'Examples' must be given")

      true ->
        changeset
    end
  end

  def validate_default_opts_is_in_values_opts(%Changeset{valid?: false} = changeset), do: changeset

  def validate_default_opts_is_in_values_opts(%Changeset{valid?: true} = changeset) do
    values_opts = get_field_from_opts(changeset, :values)
    default_opts = get_field_from_opts(changeset, :default)

    cond do
      is_nil(default_opts) or is_nil(values_opts) -> changeset
      default_opts in values_opts -> changeset
      true -> add_error(changeset, :opts_default, "expected the default value to be one of the Accepted Values list")
    end
  end

  def validate_type_and_default_opts(changeset) do
    type = get_field(changeset, :type)
    default_opts = get_field_from_opts(changeset, :default)

    Content.validate(changeset, type, default_opts, :opts_default)
  end

  def validate_type_and_examples_opts(%Changeset{valid?: false} = changeset), do: changeset

  def validate_type_and_examples_opts(%Changeset{valid?: true} = changeset) do
    type = get_field(changeset, :type)
    examples_opts = get_field(changeset, :opts) |> maybe_binary_to_term() |> Keyword.get(:examples, [])

    Enum.reduce(examples_opts, changeset, fn value, changeset -> Content.validate(changeset, type, value, :opts_examples) end)
  end

  def validate_type_and_values_opts(%Changeset{valid?: false} = changeset), do: changeset

  def validate_type_and_values_opts(%Changeset{valid?: true} = changeset) do
    type = get_field(changeset, :type)
    values_opts = get_field(changeset, :opts) |> maybe_binary_to_term() |> Keyword.get(:values, [])

    Enum.reduce(values_opts, changeset, fn value, changeset -> Content.validate(changeset, type, value, :opts_values) end)
  end

  defp get_field_from_opts(changeset, field) do
    get_field(changeset, :opts) |> maybe_binary_to_term() |> Keyword.get(field)
  end

  defp maybe_binary_to_term(opts) when is_binary(opts), do: :erlang.binary_to_term(opts)
  defp maybe_binary_to_term(opts), do: opts
end
