# https://github.com/phoenixframework/phoenix/blob/d8f7144971c3e0bb9e9e07eb5532e9fc49d2d053/lib/phoenix/verified_routes.ex

# credo:disable-for-this-file

defmodule Beacon.Loader.Routes do
  @moduledoc false
  # TODO: validate paths

  alias Beacon.Loader

  def module_name(site), do: Loader.module_name(site, "Routes")

  def build_ast(site) do
    config = Beacon.Config.fetch!(site)

    config.site
    |> module_name()
    |> render(config.site, config.endpoint, config.router)
  end

  defp render(routes_module, site, endpoint, router) do
    quote do
      defmodule unquote(routes_module) do
        Module.put_attribute(__MODULE__, :site, unquote(site))
        Module.put_attribute(__MODULE__, :endpoint, unquote(endpoint))
        Module.put_attribute(__MODULE__, :router, unquote(router))

        # TODO: secure cross site assets
        # TODO: asset_path sigil
        def beacon_asset_path(file_name) when is_binary(file_name) do
          sanitize_path("/__beacon_assets__/#{unquote(site)}/#{file_name}")
        end

        # TODO: asset_url sigil
        def beacon_asset_url(file_name) when is_binary(file_name) do
          @endpoint.url() <> beacon_asset_path(file_name)
        end

        defp sanitize_path(path) do
          String.replace(path, "//", "/")
        end

        defmacro sigil_P({:<<>>, _meta, _segments} = route, extra) do
          validate_sigil_P!(extra)
          prefix = @router.__beacon_scoped_prefix_for_site__(@site)
          build_route(route, __CALLER__, prefix, @endpoint, @router)
        end

        defp validate_sigil_P!([]), do: :ok

        defp validate_sigil_P!(extra) do
          raise ArgumentError, "~P does not support modifiers after closing, got: #{extra}"
        end

        defp build_route(route_ast, env, prefix, endpoint, router) do
          router =
            case Macro.expand(router, env) do
              mod when is_atom(mod) ->
                mod

              other ->
                raise ArgumentError, """
                expected router to be to module, got: #{inspect(other)}
                """
            end

          {:<<>>, meta, segments} = route_ast
          {path_rewrite, query_rewrite} = verify_segment(segments, route_ast)

          path_rewrite =
            if prefix in ["", "/"] do
              path_rewrite
            else
              [prefix] ++ path_rewrite
            end

          rewrite_route =
            quote generated: true do
              query_str = unquote({:<<>>, meta, query_rewrite})
              path_str = unquote({:<<>>, meta, path_rewrite})

              if query_str == "" do
                path_str
              else
                path_str <> "?" <> query_str
              end
            end

          quote generated: true do
            Phoenix.VerifiedRoutes.unverified_path(unquote_splicing([endpoint, router, rewrite_route]))
          end
        end

        defp verify_segment(["/" <> _ | _] = segments, route), do: verify_segment(segments, route, [])

        defp verify_segment(_, route) do
          raise ArgumentError, "paths must begin with /, got: #{Macro.to_string(route)}"
        end

        # separator followed by dynamic
        defp verify_segment(["/" | rest], route, acc), do: verify_segment(rest, route, ["/" | acc])

        # we've found a static segment, return to caller with rewritten query if found
        defp verify_segment(["/" <> _ = segment | rest], route, acc) do
          case {String.split(segment, "?"), rest} do
            {[segment], _} ->
              verify_segment(rest, route, [URI.encode(segment) | acc])

            {[segment, static_query], dynamic_query} ->
              {Enum.reverse([URI.encode(segment) | acc]), verify_query(dynamic_query, route, [static_query])}
          end
        end

        # we reached the static query string, return to caller
        defp verify_segment(["?" <> query], _route, acc) do
          {Enum.reverse(acc), [query]}
        end

        # we reached the dynamic query string, return to call with rewritten query
        defp verify_segment(["?" <> static_query_segment | rest], route, acc) do
          {Enum.reverse(acc), verify_query(rest, route, [static_query_segment])}
        end

        defp verify_segment([segment | _], route, _acc) when is_binary(segment) do
          raise ArgumentError,
                "path segments after interpolation must begin with /, got: #{inspect(segment)} in #{Macro.to_string(route)}"
        end

        defp verify_segment(
               [
                 {:"::", m1, [{{:., m2, [Kernel, :to_string]}, m3, [dynamic]}, {:binary, _, _} = bin]}
                 | rest
               ],
               route,
               [prev | _] = acc
             )
             when is_binary(prev) do
          rewrite = {:"::", m1, [{{:., m2, [__MODULE__, :__encode_segment__]}, m3, [dynamic]}, bin]}
          verify_segment(rest, route, [rewrite | acc])
        end

        defp verify_segment([_ | _], route, _acc) do
          raise ArgumentError,
                "a dynamic ~p interpolation must follow a static segment, got: #{Macro.to_string(route)}"
        end

        # we've reached the end of the path without finding query, return to caller
        defp verify_segment([], _route, acc), do: {Enum.reverse(acc), _query = []}

        defp verify_query(
               [
                 {:"::", m1, [{{:., m2, [Kernel, :to_string]}, m3, [arg]}, {:binary, _, _} = bin]}
                 | rest
               ],
               route,
               acc
             ) do
          unless is_binary(hd(acc)) do
            raise ArgumentError,
                  "interpolated query string params must be separated by &, got: #{Macro.to_string(route)}"
          end

          rewrite = {:"::", m1, [{{:., m2, [__MODULE__, :__encode_query__]}, m3, [arg]}, bin]}
          verify_query(rest, route, [rewrite | acc])
        end

        defp verify_query([], _route, acc), do: Enum.reverse(acc)

        defp verify_query(["=" | rest], route, acc) do
          verify_query(rest, route, ["=" | acc])
        end

        defp verify_query(["&" <> _ = param | rest], route, acc) do
          unless String.contains?(param, "=") do
            raise ArgumentError,
                  "expected query string param key to end with = or declare a static key value pair, got: #{inspect(param)}"
          end

          verify_query(rest, route, [param | acc])
        end

        defp verify_query(_other, route, _acc) do
          raise_invalid_query(route)
        end

        defp raise_invalid_query(route) do
          raise ArgumentError,
                "expected query string param to be compile-time map or keyword list, got: #{Macro.to_string(route)}"
        end
      end
    end
  end
end
