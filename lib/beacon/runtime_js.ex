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
    |> Enum.map(fn {app, asset} ->
      app
      |> Application.app_dir(["priv", "static", asset])
      |> File.read!()
      |> String.replace("//# sourceMappingURL=", "// ")
      |> String.replace("/* BEACON_HOOKS */", build_hooks(site, minify?))
    end)
    |> IO.iodata_to_binary()
  end

  def fetch(site) do
    case :ets.match(:beacon_assets, {{site, :js}, {:_, :_, :"$1"}}) do
      [[js]] -> js
      _ -> "// JS not found"
    end
  end

  def load!(site) do
    js = build(site)

    case ExBrotli.compress(js) do
      {:ok, compressed} ->
        hash = Base.encode16(:crypto.hash(:md5, js), case: :lower)
        true = :ets.insert(:beacon_assets, {{site, :js}, {hash, js, compressed}})
        :ok

      error ->
        raise Beacon.LoaderError, "failed to compress js: #{inspect(error)}"
    end
  end

  def current_hash(site) do
    case :ets.match(:beacon_assets, {{site, :js}, {:"$1", :_, :_}}) do
      [[hash]] -> hash
      _ -> nil
    end
  end

  def build_hooks(site, minify?) do
    joiner = if(minify?, do: ",", else: ",\n")

    site
    |> Beacon.Content.list_js_hooks()
    |> Enum.map_join(joiner, fn hook ->
      code =
        IO.iodata_to_binary([
          if(hook.mounted, do: format_callback(hook, :mounted, minify?), else: []),
          if(hook.beforeUpdate, do: format_callback(hook, :beforeUpdate, minify?), else: []),
          if(hook.updated, do: format_callback(hook, :updated, minify?), else: []),
          if(hook.destroyed, do: format_callback(hook, :destroyed, minify?), else: []),
          if(hook.disconnected, do: format_callback(hook, :disconnected, minify?), else: []),
          if(hook.reconnected, do: format_callback(hook, :reconnected, minify?), else: [])
        ])

      if minify? do
        "#{hook.name}:{#{code}}"
      else
        "    #{hook.name}: {\n#{code}    }"
      end
    end)
  end

  defp format_callback(hook, callback, minify?)

  defp format_callback(hook, callback, false) do
    IO.iodata_to_binary([
      "      ",
      to_string(callback),
      "() {\n        ",
      hook |> Map.fetch!(callback) |> String.trim_trailing() |> String.replace("\n", "\n        "),
      "\n      },\n"
    ])
  end

  defp format_callback(hook, callback, true) do
    IO.iodata_to_binary([
      to_string(callback),
      "(){",
      hook |> Map.fetch!(callback) |> String.replace("\n", ""),
      "},"
    ])
  end
end
