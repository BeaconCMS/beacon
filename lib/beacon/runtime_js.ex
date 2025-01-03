defmodule Beacon.RuntimeJS do
  # Runtime compilation and processing of JS files.
  @moduledoc false

  # merge beacon js with host application dependencies js
  # similar to https://github.com/phoenixframework/phoenix_live_dashboard/blob/9140f56c34201237f0feeeff747528eed2795c0c/lib/phoenix/live_dashboard/controllers/assets.ex#L6-L11
  # TODO: build and minfy at runtime with esbuild
  def build(site) do
    assets =
      if Code.ensure_loaded?(Mix.Project) and Mix.env() in [:test, :dev] do
        [
          phoenix: "phoenix.js",
          phoenix_html: "phoenix_html.js",
          phoenix_live_view: "phoenix_live_view.js",
          beacon: "beacon.js"
        ]
      else
        [
          phoenix: "phoenix.min.js",
          phoenix_html: "phoenix_html.js",
          phoenix_live_view: "phoenix_live_view.min.js",
          beacon: "beacon.min.js"
        ]
      end

    assets
    |> Enum.map(fn {app, asset} ->
      app
      |> Application.app_dir(["priv", "static", asset])
      |> File.read!()
      |> String.replace("//# sourceMappingURL=", "// ")
      |> String.replace("// BEACON_HOOKS", get_hooks(site))
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
      _ -> ""
    end
  end

  defp get_hooks(site) do
    site
    |> Beacon.Content.list_js_hooks()
    |> Enum.map_join(",\n", fn hook ->
      "#{hook.name}: { #{hook.content} }"
    end)
  end
end
