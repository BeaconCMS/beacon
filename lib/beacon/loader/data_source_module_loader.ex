defmodule Beacon.Loader.DataSourceModuleLoader do
  @moduledoc false
  alias Beacon.Loader

  require Logger

  def load_data_source(site, data) do
    data_source_module = Loader.data_source_module_for_site(site)
    data_by_path = Enum.group_by(data, & &1.path)
    live_data_functions = Enum.map(data_by_path, &live_data_fn/1)
    # TODO
    default_data = %{}

    ast =
      quote do
        defmodule unquote(data_source_module) do
          @behaviour Beacon.DataSource.Behaviour
          require Logger

          @impl Beacon.DataSource.Behaviour
          def live_data(path, params) do
            live_data(path, params, unquote(default_data))
          end

          unquote_splicing(live_data_functions)

          def live_data(path, params, data) do
            Logger.warning("Unhandled Beacon Live Data request for site #{unquote(site)} with path #{inspect(path)} and params #{inspect(params)}")
            data
          end
        end
      end

    :ok = Loader.reload_module!(data_source_module, ast)

    {:ok, ast}
  end

  defp live_data_fn({path, data_list}) do
    path_list =
      quote do
        unquote(path)
        |> String.split("/", trim: true)
        |> Enum.map(fn
          ":" <> param -> var!(Macro.unique_var(param, nil))
          param -> param
        end)
      end

    quote do
      def live_data(unquote(path_list), var!(params), var!(data)) do
        Enum.reduce(unquote(data_list), var!(data), fn live_data, acc ->
          Map.put(
            acc,
            live_data.assign,
            case live_data.format do
              :text -> live_data.code
              :elixir -> Code.string_to_quoted!(live_data.code)
            end
          )
        end)
      end
    end
  end
end
