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

    # hooks (simulate hooks defined in live admin)
    # 1. concat all hooks
    # 2. export them into as a single object
    # 3. bundle for browser using esbuild
    #
    # // hook 1
    # const ConsoleLogHook = {
    #   mounted() {
    #     console.log("mounted")
    #   }
    # }
    #
    # export default {
    #   ConsoleLogHook,
    # }

    # step 3
    # results in the `hooks` string below
    # which creates `window.BeaconHooks` when evaluated by the browser
    # _build/esbuild-darwin-arm64 hook.js --bundle --minify --format=iife --target=es2016 --platform=browser --global-name=BeaconHooks

    # TODO: delete tmp files after
    tmp_dir = tmp_dir!()

    hook_a_path = Path.join(tmp_dir, "hook_a.js")
    File.write!(hook_a_path, ~s"""
    const message = "mounted"

    const ConsoleLogHook = {
      mounted() {
        console.log(message)
      }
    }

    export default ConsoleLogHook
    """)

    hooks_js_path = Path.join(tmp_dir, "hooks.js") |> dbg

    hooks = ~s"""
    import ConsoleLogHook from '#{hook_a_path}'

    export default {
      ConsoleLogHook,
    }
    """

    File.write!(hooks_js_path, hooks)

    # TODO: minify on/off
    args = ~w(#{hooks_js_path} --bundle --minify --format=iife --target=es2016 --platform=browser --global-name=BeaconHooks) |> dbg
    opts = [cd: File.cwd!(), stderr_to_stdout: true]

    # TODO: check if esbuild bin exist, similar to TailwindCompiler
    # TODO: copy esbuild bin into the release
    # TODO: handle errors
    {hooks, 0} = System.cmd(Esbuild.bin_path(), args, opts) |> dbg

    js_deps =
      assets
      |> Enum.map(fn {app, asset} ->
        app
        |> Application.app_dir(["priv", "static", asset])
        |> File.read!()
        |> String.replace("//# sourceMappingURL=", "// ")
      end)

    js_deps = [hooks, "\n", js_deps]

    IO.iodata_to_binary(js_deps)
  end

  defp tmp_dir! do
    tmp_dir = Path.join(System.tmp_dir!(), random_dir())
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end

  defp random_dir, do: :crypto.strong_rand_bytes(12) |> Base.encode16()

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

    try do
      :ets.insert(:beacon_assets, {{site, :js}, {hash, js, brotli, gzip}})
    rescue
      _ -> raise Beacon.LoaderError, "failed to compress js"
    end

    :ok
  end

  def current_hash(site) do
    case :ets.match(:beacon_assets, {{site, :js}, {:"$1", :_, :_, :_}}) do
      [[hash]] -> hash
      _ -> nil
    end
  end
end
