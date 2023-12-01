defmodule Beacon.Loader.DataSourceModuleLoader do
  @moduledoc false
  alias Beacon.Loader

  require Logger

  def load_data_source(site, data) do
    data_source_module = Loader.data_source_module_for_site(site)
    data_by_path = Enum.group_by(data, & &1.path)
    live_data_functions = Enum.map(data_by_path, &live_data_fn/1)
    # TODO default data

    ast =
      quote do
        defmodule unquote(data_source_module) do
          @behaviour Beacon.DataSource.Behaviour
          require Logger

          @impl Beacon.DataSource.Behaviour
          def live_data(path, params) do
            live_data(path, params, %{})
          end

          unquote_splicing(live_data_functions)

          def live_data(path, params, data) do
            Logger.warning("Unhandled Beacon Live Data request for site #{unquote(site)} with path #{inspect(path)} and params #{inspect(params)}")
            data
          end
        end
      end

    # For debugging - will print module content to the terminal
    ast
    |> Code.quoted_to_algebra()
    |> Inspect.Algebra.format(:infinity)
    |> IO.iodata_to_binary()
    |> IO.puts()

    :ok = Loader.reload_module!(data_source_module, ast)

    {:ok, ast}
  end

  defp live_data_fn({path, data_list}) do
    path_list =
      quote do
        unquote(
          path
          |> String.split("/", trim: true)
          |> Enum.map(fn
            ":" <> param -> Macro.var(:"#{param}", :"#{path}")
            param -> param
          end)
        )
      end

    bindings =
      quote do
        unquote(
          path
          |> String.split("/", trim: true)
          |> Enum.filter(&String.starts_with?(&1, ":"))
          |> Keyword.new(fn ":" <> param ->
            {:"#{param}", Macro.var(:"#{param}", :"#{path}")}
          end)
        )
      end

    quote do
      def live_data(unquote(path_list), var!(params), var!(data)) do
        Enum.reduce(unquote(Macro.escape(data_list)), var!(data), fn live_data, acc ->
          Map.put(
            acc,
            String.to_atom(live_data.assign),
            case live_data.format do
              :text -> live_data.code
              :elixir -> live_data.code |> Code.eval_string(unquote(bindings), __ENV__) |> elem(0)
            end
          )
        end)
      end
    end
  end
end
