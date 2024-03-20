defmodule Beacon.Compiler do
  @moduledoc false

  require Logger
  alias Beacon.Loader

  @type diagnostics :: [Code.diagnostic(:warning | :error)]

  @spec compile_module(Beacon.Site.t(), Macro.t(), String.t()) ::
          {:ok, module(), diagnostics()} | {:error, module(), {Exception.t(), diagnostics()}} | {:error, :invalid_module}
  def compile_module(site, quoted, file \\ "nofile") do
    case module_name(quoted) do
      {:ok, module} ->
        quoted_md5 = md5(quoted)
        do_compile_module(site, module, quoted, quoted_md5, file)

      {:error, error} ->
        {:error, error}
    end
  end

  defp do_compile_module(site, module, quoted, quoted_md5, file) do
    case {:erlang.module_loaded(module), current_module_md5(site, module) == quoted_md5} do
      {true, true} ->
        {:ok, module, []}

      {true, _} ->
        unload(module)
        compile_and_register(site, module, quoted, quoted_md5, file)

      {false, _} ->
        compile_and_register(site, module, quoted, quoted_md5, file)
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

  defp compile_and_register(site, module, quoted, quoted_md5, file) do
    case compile_quoted(quoted, file) do
      {:ok, module, diagnostics} ->
        add_module(site, module, quoted_md5, nil, diagnostics)
        {:ok, module, diagnostics}

      {:error, error, diagnostics} ->
        add_module(site, module, quoted_md5, error, diagnostics)
        {:error, module, {error, diagnostics}}

      {:error, error} ->
        add_module(site, module, quoted_md5, nil, nil)
        {:error, error}
    end
  end

  if Version.match?(System.version(), ">= 1.15.0") do
    defp compile_quoted(quoted, file) do
      {result, diagnostics} =
        Code.with_diagnostics(fn ->
          try do
            [{module, _}] = Code.compile_quoted(quoted, file)
            {:module, ^module} = Code.ensure_loaded(module)
            {:ok, module}
          rescue
            error -> {:error, error}
          end
        end)

      case result do
        {:ok, module} ->
          {:ok, module, diagnostics}

        {:error, error} ->
          {:error, error, diagnostics}
      end
    end
  else
    defp compile_quoted(quoted, file) do
      [{module, _}] = Code.compile_quoted(quoted, file)
      {:module, ^module} = Code.ensure_loaded(module)
      {:ok, module, []}
    rescue
      error -> {:error, error, []}
    end
  end

  def unload(module) do
    :code.purge(module)
    :code.delete(module)
  end

  defp add_module(site, module, md5, error, diagnostics) do
    :ok = Loader.add_module(site, module, {md5, error, diagnostics})
  end

  defp current_module_md5(site, module) do
    case Loader.lookup_module(site, module) do
      {^module, {md5, _, _}} -> md5
      _ -> nil
    end
  end

  defp md5(quoted) do
    binary = quoted_to_binary(quoted)
    Base.encode16(:crypto.hash(:md5, binary), case: :lower)
  end

  defp quoted_to_binary(quoted) do
    quoted
    |> Code.quoted_to_algebra()
    |> Inspect.Algebra.format(:infinity)
    |> IO.iodata_to_binary()
  end
end
