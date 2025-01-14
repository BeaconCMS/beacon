defmodule Beacon.RuntimeJS do
  # Runtime compilation and processing of JS files.
  @moduledoc false

  # merge beacon js with host application dependencies js
  # similar to https://github.com/phoenixframework/phoenix_live_dashboard/blob/9140f56c34201237f0feeeff747528eed2795c0c/lib/phoenix/live_dashboard/controllers/assets.ex#L6-L11
  # TODO: build and minfy at runtime with esbuild
  def build do
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
    end)
    |> IO.iodata_to_binary()
  end

  def fetch(version \\ :brotli)
  def fetch(:brotli), do: do_fetch({:_, :_, :"$1", :_})
  def fetch(:gzip), do: do_fetch({:_, :_, :_, :"$1"})
  def fetch(:deflate), do: do_fetch({:_, :"$1", :_, :_})

  defp do_fetch(guard) do
    case :ets.match(:beacon_assets, {:js, guard}) do
      [[js]] -> js
      _ -> "// JS not found"
    end
  end

  def load! do
    js = build()

    hash = Base.encode16(:crypto.hash(:md5, js), case: :lower)

    brotli =
      case ExBrotli.compress(js) do
        {:ok, content} -> content
        _ -> nil
      end

    gzip = :zlib.gzip(js)

    if :ets.insert(:beacon_assets, {:js, {hash, js, brotli, gzip}}) do
      :ok
    else
      raise Beacon.LoaderError, "failed to compress js"
    end
  end

  def current_hash do
    case :ets.match(:beacon_assets, {:js, {:"$1", :_, :_, :_}}) do
      [[hash]] -> hash
      _ -> nil
    end
  end
end
