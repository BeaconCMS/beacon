defmodule Beacon.Compiler do
  @moduledoc false

  require Logger
  alias Beacon.Loader

  if Beacon.Config.env_test?() do
    @max_retries 2
  else
    @max_retries 10
  end

  @type diagnostics :: [Code.diagnostic(:warning | :error)]

  @spec compile_module(Beacon.Site.t(), Macro.t(), String.t()) ::
          {:ok, module(), diagnostics()} | {:error, module(), {Exception.t(), diagnostics()}} | {:error, Exception.t() | :invalid_module}
  def compile_module(site, quoted, file \\ "nofile") do
    case module_name(quoted) do
      {:ok, module} ->
        do_compile_module(site, module, quoted, hash(quoted), file)

      {:error, error} ->
        {:error, error}
    end
  end

  defp do_compile_module(site, module, quoted, hash, file) do
    case {:erlang.module_loaded(module), current_hash(site, module) == hash} do
      {true, true} ->
        {:ok, module, []}

      {true, _} ->
        unload(module)
        compile_and_register(site, module, quoted, hash, file)

      {false, _} ->
        compile_and_register(site, module, quoted, hash, file)
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

      Got: #{inspect(quoted)}

    """)

    {:error, :invalid_module}
  end

  defp compile_and_register(site, module, quoted, hash, file) do
    case compile_quoted(quoted, file) do
      {:ok, module, diagnostics} ->
        add_module(site, module, hash, nil, diagnostics)
        {:ok, module, diagnostics}

      {:error, error, diagnostics} ->
        add_module(site, module, hash, error, diagnostics)
        {:error, module, {error, diagnostics}}

      {:error, error} ->
        add_module(site, module, hash, error, nil)
        {:error, error}
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

  defp do_compile_and_load(quoted, file, failure_count \\ 0) do
    [{module, _}] = Code.compile_quoted(quoted, file)
    {:module, ^module} = Code.ensure_loaded(module)
    {:ok, module}
  rescue
    error in CompileError ->
      if failure_count < @max_retries do
        :timer.sleep(100 * (failure_count * 2))
        do_compile_and_load(quoted, file, failure_count + 1)
      else
        {:error, error}
      end

    error ->
      {:error, error}
  end

  def unload(module) do
    :code.purge(module)
    :code.delete(module)
  end

  defp add_module(site, module, hash, error, diagnostics) do
    :ok = Loader.add_module(site, module, {hash, error, diagnostics})
  end

  defp current_hash(site, module) do
    case Loader.lookup_module(site, module) do
      {^module, {hash, _, _}} -> hash
      _ -> nil
    end
  end

  defp hash(quoted) do
    :erlang.phash2(quoted)
  end
end
