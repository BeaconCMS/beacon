defmodule Beacon.Compiler do
  @moduledoc false

  require Logger

  @type diagnostics :: [Code.diagnostic(:warning | :error)]

  @spec compile_module(Macro.t(), String.t()) ::
          {:ok, module(), diagnostics()} | {:error, module(), {Exception.t(), diagnostics()}} | {:error, Exception.t() | :invalid_module}
  def compile_module(quoted, file \\ "nofile") do
    Logger.debug("compiling #{inspect(file)}")

    case module_name(quoted) do
      {:ok, module} ->
        # unload(module)
        compile(module, quoted, file)

      {:error, error} ->
        {:error, error}
    end
  end

  def module_name({:defmodule, _, [{:__aliases__, _, [module]}, _]}) do
    {:ok, Module.concat([module])}
  end

  def module_name({:defmodule, _, [module, _]}) do
    {:ok, Module.concat([module])}
  end

  def module_name({module, {:defmodule, _, _}}) do
    {:ok, Module.concat([module])}
  end

  def module_name(quoted) do
    Logger.error("""
    invalid module given to Beacon.Compiler,
    expected a quoted expression containing a single module.

    Got:

      #{inspect(quoted)}

    """)

    {:error, :invalid_module}
  end

  defp compile(module, quoted, file) do
    Code.put_compiler_option(:ignore_module_conflict, true)

    case compile_quoted(quoted, file) do
      {:ok, module, diagnostics} ->
        {:ok, module, diagnostics}

      {:error, error, diagnostics} ->
        {:error, module, {error, diagnostics}}
    end
  end

  if Version.match?(System.version(), ">= 1.15.0") do
    defp compile_quoted(quoted, file) do
      {result, diagnostics} = Code.with_diagnostics(fn -> do_compile_and_load(quoted, file) end)
      diagnostics = Enum.uniq(diagnostics)

      case result do
        {:ok, module} ->
          {:ok, module, diagnostics}

        {:error, error} ->
          {:error, error, diagnostics}
      end
    end
  else
    defp compile_quoted(quoted, file) do
      case do_compile_and_load(quoted, file) do
        {:ok, module} -> {:ok, module, []}
        {:error, error} -> {:error, error, []}
      end
    end
  end

  defp do_compile_and_load(quoted, file) do
    [{module, _}] = :elixir_compiler.quoted(quoted, file, fn _, _ -> :ok end)
    {:ok, module}
  rescue
    error ->
      {:error, error}
  end
end
