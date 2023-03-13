defmodule Beacon.RuntimeJS do
  # Runtime compilation and processing of JS files.
  @moduledoc false

  # merge beacon js with host application dependencies js
  # similar to https://github.com/phoenixframework/phoenix_live_dashboard/blob/9140f56c34201237f0feeeff747528eed2795c0c/lib/phoenix/live_dashboard/controllers/assets.ex#L6-L11
  # TODO: build and minfy at runtime with esbuild
  def build(site) when is_atom(site) do
    assets =
      if Code.ensure_loaded?(Mix.Project) and Mix.env() in [:test, :dev] do
        [phoenix: "phoenix.js", phoenix_html: "phoenix_html.js", phoenix_live_view: "phoenix_live_view.js", beacon: "beacon.js"]
      else
        [phoenix: "phoenix.min.js", phoenix_html: "phoenix_html.js", phoenix_live_view: "phoenix_live_view.min.js", beacon: "beacon.min.js"]
      end

    assets
    |> Enum.map(fn {app, asset} ->
      app
      |> Application.app_dir(["priv", "static", asset])
      |> File.read!()
      |> String.replace("//# sourceMappingURL=", "// ")
    end)
    |> IO.iodata_to_binary()
  end

  @doc false
  def fetch(site) do
    case :ets.match(:beacon_assets, {{site, :js}, {:_, :"$1"}}) do
      [[js]] -> js
      _ -> "// JS not found for site #{inspect(site)} */"
    end
  end

  @doc false
  def load(site) do
    js = build(site)
    hash = Base.encode16(:crypto.hash(:md5, js), case: :lower)
    :ets.insert(:beacon_assets, {{site, :js}, {hash, js}})
  end

  def current_hash(site) do
    case :ets.match(:beacon_assets, {{site, :js}, {:"$1", :_}}) do
      [[hash]] -> hash
      _ -> ""
    end
  end
end
