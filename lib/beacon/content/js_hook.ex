defmodule Beacon.Content.JSHook do
  @moduledoc """
  Stores a JS Hook which can be referenced from your Beacon pages, layouts, and components.

  > #### Do not create or edit JS Hooks manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """
  use Beacon.Schema

  @type t :: %__MODULE__{}

  schema "beacon_js_hooks" do
    field :name, :string
    field :site, Beacon.Types.Site
    field :code, :string

    timestamps()
  end

  @doc false
  # TODO: validate name is a valid JS object name
  def changeset(js_hook, attrs) do
    fields = [:name, :site, :code]

    js_hook
    |> cast(attrs, fields)
    |> validate_required(fields)
    |> validate_code()
  end

  @doc false
  def validate_code(changeset) do
    hook = apply_changes(changeset)

    validate_change(changeset, :code, fn :code, _code ->
      case get_export(hook) do
        {:ok, export} when export in ["default", hook.name] -> []
        {:ok, export} -> [name: {"does not match export", export: export}]
        {:error, :no_export} -> [code: "no export found"]
        {:error, :multiple_exports} -> [code: "multiple exports are not allowed"]
        {:error, _} -> [code: "syntax error: please double-check your code and try again"]
      end
    end)
  end

  @doc false
  def get_export(hook, dir \\ tmp_dir!()) do
    with %{"outputs" => %{} = outputs} <- get_code_metadata(hook, dir),
         {_, %{"exports" => exports}} <- Enum.at(outputs, 0) do
      case exports do
        [] -> {:error, :no_export}
        [export] -> {:ok, export}
        exports when is_list(exports) -> {:error, :multiple_exports}
        _ -> {:error, :unknown}
      end
    else
      _ -> {:error, :esbuild_failed}
    end
  end

  @doc false
  @spec get_code_metadata(t(), String.t()) :: map() | nil
  def get_code_metadata(hook, dir \\ tmp_dir!()) do
    hook_js_path = Path.join(dir, hook.name <> ".js")
    meta_json_path = Path.join(dir, hook.name <> ".json")
    meta_out_js_path = Path.join(dir, hook.name <> "_meta.js")
    cmd_opts = [cd: File.cwd!(), stderr_to_stdout: true]

    File.write!(hook_js_path, hook.code)

    {_, 0} = System.cmd(Esbuild.bin_path(), ~w(#{hook_js_path} --metafile=#{meta_json_path} --outfile=#{meta_out_js_path}), cmd_opts)

    with {:ok, meta} <- File.read(meta_json_path),
         {:ok, meta} <- Jason.decode(meta) do
      meta
    else
      _ -> nil
    end
  end

  defp tmp_dir! do
    tmp_dir = Path.join(System.tmp_dir!(), random_dir())
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end

  defp random_dir do
    12 |> :crypto.strong_rand_bytes() |> Base.encode16()
  end
end
