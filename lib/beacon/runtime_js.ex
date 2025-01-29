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

    # TODO: delete tmp files after
    tmp_dir = tmp_dir!()
    cmd_opts = [cd: File.cwd!(), stderr_to_stdout: true]

    {hooks, imports} =
      Enum.reduce(Beacon.Content.list_js_hooks(site), {[], []}, fn hook, {hooks, imports} = acc ->
        hook_js_path = Path.join(tmp_dir, hook.name <> ".js")
        meta_json_path = Path.join(tmp_dir, hook.name <> ".json")
        meta_out_js_path = Path.join(tmp_dir, hook.name <> "_meta.js")

        File.write!(hook_js_path, hook.code)

        {_, 0} = System.cmd(Esbuild.bin_path(), ~w(#{hook_js_path} --metafile=#{meta_json_path} --outfile=#{meta_out_js_path}), cmd_opts)

        # TODO: handle errors (invalid json or more than one export, it should have a single export)
        export =
          with {:ok, meta} <- File.read(meta_json_path),
               {:ok, meta} <- Jason.decode(meta),
               {_, meta} <- Enum.at(meta["outputs"] || %{}, 0),
               [export] <- meta["exports"] do
            export
          else
            _ -> nil
          end

        import =
          cond do
            export == "default" ->
              "import #{hook.name} from '#{hook_js_path}';"

            is_binary(export) ->
              "import { #{export} as #{hook.name} } from '#{hook_js_path}';"

            :else ->
              nil
          end

        if import do
          {[hook.name | hooks], [import | imports]}
        else
          # TODO: warn? error?
          acc
        end
      end)

    hooks = [
      Enum.intersperse(imports, "\n"),
      "\n",
      "export default {\n",
      Enum.intersperse(hooks, ",\n"),
      "\n}"
    ]

    IO.puts(hooks)

    hooks_js_path = Path.join(tmp_dir, "hooks.js")
    File.write!(hooks_js_path, hooks)

    # TODO: minify on/off (--minify)
    args = ~w(#{hooks_js_path} --bundle --format=iife --target=es2016 --platform=browser --global-name=BeaconHooks --log-level=error)

    # TODO: check if esbuild bin exist, similar to TailwindCompiler
    # TODO: copy esbuild bin into the release
    # TODO: handle errors (exit != 0)
    {hooks, 0} = System.cmd(Esbuild.bin_path(), args, cmd_opts)

    js_deps =
      assets
      |> Enum.map(fn {app, asset} ->
        app
        |> Application.app_dir(["priv", "static", asset])
        |> File.read!()
        |> String.replace("//# sourceMappingURL=", "// ")
      end)

    IO.iodata_to_binary([hooks, "\n", js_deps])
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
      _ -> reraise Beacon.LoaderError, [message: "failed to compress js"], __STACKTRACE__
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
