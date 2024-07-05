defmodule Beacon.RuntimeTailwind do
  # Runtime compilation and processing of Tailwind Configuration files.
  @moduledoc false
  def build do
    [beacon: "tailwind.config.js"]
    |> Enum.map(fn {app, asset} ->
      app
      |> Application.app_dir(["priv", "static", asset])
      |> File.read!()
      |> String.replace("//# sourceMappingURL=", "// ")
    end)
    |> IO.iodata_to_binary()
  end

  def fetch do
    case :ets.match(:beacon_assets, {:tailwind_config, {:_, :_, :"$1"}}) do
      [[config]] -> config
      _ -> "// Tailwind Config not found"
    end
  end

  def load! do
    config = build()

    hash = Base.encode16(:crypto.hash(:md5, config), case: :lower)
    true = :ets.insert(:beacon_assets, {:tailwind_config, {hash, config, config}})
    :ok
  end

  def current_hash do
    case :ets.match(:beacon_assets, {:tailwind_config, {:"$1", :_, :_}}) do
      [[hash]] -> hash
      _ -> ""
    end
  end
end
