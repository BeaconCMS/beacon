defmodule Beacon.RuntimeJS do
  # Runtime compilation and processing of JS files.
  @moduledoc false

  # merge beacon js with host application dependencies js
  # similar to https://github.com/phoenixframework/phoenix_live_dashboard/blob/9140f56c34201237f0feeeff747528eed2795c0c/lib/phoenix/live_dashboard/controllers/assets.ex#L6-L11
  # TODO: build and minfy at runtime with esbuild
  def build(site) do
    minify? = !(Code.ensure_loaded?(Mix.Project) and Mix.env() in [:test, :dev])

    assets =
      if minify? do
        [
          phoenix: "phoenix.min.js",
          phoenix_html: "phoenix_html.js",
          phoenix_live_view: "phoenix_live_view.min.js",
          beacon: "beacon.min.js"
        ]
      else
        [
          phoenix: "phoenix.js",
          phoenix_html: "phoenix_html.js",
          phoenix_live_view: "phoenix_live_view.js",
          beacon: "beacon.js"
        ]
      end

    assets
    |> Enum.map(fn
      {:beacon, asset} ->
        :beacon
        |> Application.app_dir(["priv", "static", asset])
        |> File.read!()
        |> String.replace(~r/hooks:.*{}/, build_hooks(site, minify?))

      {app, asset} ->
        app
        |> Application.app_dir(["priv", "static", asset])
        |> File.read!()
        |> String.replace("//# sourceMappingURL=", "// ")
    end)
    |> IO.iodata_to_binary()
  end

  def fetch(site, version \\ :brotli)
  def fetch(site, :brotli), do: do_fetch(site, {:_, :_, :"$1", :_})
  def fetch(site, :gzip), do: do_fetch(site, {:_, :_, :_, :"$1"})
  def fetch(site, :deflate), do: do_fetch(site, {:_, :"$1", :_, :_})

  defp do_fetch(site, guard) do
    case :ets.match(:beacon_assets, {{site, :js}, guard}) do
      [[js]] -> js
      _ -> "// JS not found"
    end
  end

  def load!(site) do
    js = build(site)

    hash = Base.encode16(:crypto.hash(:md5, js), case: :lower)

    brotli =
      case ExBrotli.compress(js) do
        {:ok, content} -> content
        _ -> nil
      end

    gzip = :zlib.gzip(js)

    if :ets.insert(:beacon_assets, {{site, :js}, {hash, js, brotli, gzip}}) do
      :ok
    else
      raise Beacon.LoaderError, "failed to compress js"
    end
  end

  def current_hash(site) do
    case :ets.match(:beacon_assets, {{site, :js}, {:"$1", :_, :_, :_}}) do
      [[hash]] -> hash
      _ -> nil
    end
  end

  def build_hooks(site, minify?) do
    joiner = if(minify?, do: ",", else: ",\n")

    site
    |> Beacon.Content.list_js_hooks()
    |> Enum.map_join(joiner, fn hook ->
      callbacks =
        hook
        |> Map.take([:mounted, :before_update, :updated, :destroyed, :disconnected, :reconnected])
        |> Map.reject(fn {_k, v} -> is_nil(v) end)
        |> Enum.map(&format_callback(&1, minify?))

      hooks =
        if minify? do
          ["hooks: {", hook.name, ":{", callbacks, "}", "}"]
        else
          ["hooks: {\n    ", hook.name, ": {\n", callbacks, "    }", "\n}\n"]
        end

      IO.iodata_to_binary(hooks)
    end)
  end

  defp format_callback(kv_pair, minify?)

  defp format_callback({callback_key, code}, false) do
    [
      "      ",
      format_key(callback_key),
      "() {\n        ",
      code |> String.trim_trailing() |> String.replace("\n", "\n        "),
      "\n      },\n"
    ]
  end

  defp format_callback({callback_key, code}, true) do
    [
      format_key(callback_key),
      "(){",
      String.replace(code, "\n", ""),
      "},"
    ]
  end

  defp format_key(:before_update), do: "beforeUpdate"
  defp format_key(other), do: to_string(other)
end
