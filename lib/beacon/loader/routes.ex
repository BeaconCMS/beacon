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
    |> render(config)
  end

  defp render(routes_module, config) do
    %{site: site, endpoint: endpoint, router: router} = config

    quote do
      defmodule unquote(routes_module) do
        Module.put_attribute(__MODULE__, :site, unquote(site))
        Module.put_attribute(__MODULE__, :endpoint, unquote(endpoint))
        Module.put_attribute(__MODULE__, :router, unquote(router))

        @deprecated "use beacon_media_path/1 instead"
        def beacon_asset_path(file_name) when is_binary(file_name) do
          beacon_media_path(file_name)
        end

        @deprecated "use beacon_media_url/1 instead"
        def beacon_asset_url(file_name) when is_binary(file_name) do
          beacon_media_url(file_name)
        end

        # TODO: secure cross site assets
        # TODO: media_path sigil
        @doc """
        Media path relative to host
        """
        def beacon_media_path(file_name) when is_binary(file_name) do
          prefix = @router.__beacon_scoped_prefix_for_site__(@site)
          sanitize_path("#{prefix}/__beacon_media__/#{file_name}")
        end

        # TODO: media_url sigil
        def beacon_media_url(file_name) when is_binary(file_name) do
          public_site_host() <> beacon_media_path(file_name)
        end

        def public_site_host do
          uri = Beacon.ProxyEndpoint.public_uri(@site)
          String.Chars.URI.to_string(%URI{scheme: uri.scheme, host: uri.host, port: uri.port})
        end

        @doc """
        Returns the full public-facing site URL, including the prefix.

        Scheme and port are fetched from the Proxy Endpoint, if available,
        since that's the entry point for all requests.

        Host is fetched from the site endpoint.
        """
        def public_site_url do
          uri =
            case Beacon.ProxyEndpoint.public_uri(@site) do
              # remove path: "/"  to build URL without the / suffix
              %{path: "/"} = uri -> %{uri | path: nil}
              uri -> uri
            end

          String.Chars.URI.to_string(uri)
        end

        def public_page_url(%{site: site} = page) do
          site == @site || raise Beacon.RuntimeError, message: "failed to generate public page url "
          prefix = @router.__beacon_scoped_prefix_for_site__(@site)
          path = sanitize_path("#{prefix}#{page.path}")
          String.Chars.URI.to_string(%{Beacon.ProxyEndpoint.public_uri(@site) | path: path})
        end

        def public_sitemap_url do
          public_site_url() <> "/sitemap.xml"
        end

        def public_css_config_url do
          public_site_url() <> "/__beacon_assets__/css_config"
        end

        # TODO: remove sanitize_path/1
        defp sanitize_path(path) do
          String.replace(path, "//", "/")
        end

        defmacro sigil_p({:<<>>, _meta, _segments} = route, extra) do
          validate_sigil_p!(extra)
          prefix = @router.__beacon_scoped_prefix_for_site__(@site)
          build_route(route, __CALLER__, prefix, @endpoint, @router)
        end

        defp validate_sigil_p!([]), do: :ok

        defp validate_sigil_p!(extra) do
          raise ArgumentError, "~p does not support modifiers after closing, got: #{extra}"
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
            cond do
              prefix in ["", "/"] -> path_rewrite
              is_binary(prefix) and path_rewrite == ["/"] -> [prefix]
              :else -> [prefix] ++ path_rewrite
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

        @doc false
        def __encode_segment__(data) do
          case data do
            [] -> ""
            [str | _] when is_binary(str) -> Enum.map_join(data, "/", &encode_segment/1)
            _ -> encode_segment(data)
          end
        end

        defp encode_segment(data) do
          data
          |> Phoenix.Param.to_param()
          |> URI.encode(&URI.char_unreserved?/1)
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
