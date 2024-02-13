defmodule Beacon.Loader.DataSourceModuleLoader do
  @moduledoc false
  alias Beacon.Loader

  require Logger

  def load_data_source(data, site) do
    data_source_module = Loader.data_source_module_for_site(site)
    live_data_functions = Enum.map(data, &live_data_fn/1)

    # TODO: let users customize this
    default_data = %{}

    ast =
      quote do
        defmodule unquote(data_source_module) do
          require Logger

          def live_data(path, params) do
            live_data(path, params, unquote(Macro.escape(default_data)))
          end

          unquote_splicing(live_data_functions)

          def live_data(path, params, data) do
            Logger.warning("Unhandled Beacon Live Data request for site #{unquote(site)} with path #{inspect(path)} and params #{inspect(params)}")
            data
          end
        end
      end

    :ok = Loader.reload_module!(data_source_module, ast)

    {:ok, data_source_module, ast}
  end

  defp live_data_fn(live_data) do
    %{path: path, assigns: assigns} = live_data

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

    params_var =
      quote do
        unquote(Macro.var(:params, :"#{path}"))
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
          |> Keyword.put(:params, Macro.var(:params, :"#{path}"))
        )
      end

    quote do
      def live_data(unquote(path_list), unquote(params_var), var!(data)) do
        Enum.reduce(unquote(Macro.escape(assigns)), var!(data), fn assign, acc ->
          Map.put(
            acc,
            String.to_atom(assign.key),
            case assign.format do
              :text -> assign.value
              :elixir -> assign.value |> Code.eval_string(unquote(bindings), __ENV__) |> elem(0)
            end
          )
        end)
      end
    end
  end
end
