defmodule Beacon.Loader.LiveData do
  @moduledoc false

  alias Beacon.Loader

  def module_name(site), do: Loader.module_name(site, "LiveData")

  def build_ast(site, live_data) do
    module = module_name(site)
    live_data_functions = Enum.map(live_data, &live_data_fn/1)

    quote do
      defmodule unquote(module) do
        require Logger

        unquote_splicing(live_data_functions)

        def live_data(path, params) do
          Logger.warning("live data not found for site #{unquote(site)} with path #{inspect(path)} and params #{inspect(params)}")
          %{}
        end
      end
    end
  end

  # TODO: support glob-like patterns
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
      def live_data(unquote(path_list), unquote(params_var)) do
        Enum.reduce(unquote(Macro.escape(assigns)), %{}, fn assign, acc ->
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
