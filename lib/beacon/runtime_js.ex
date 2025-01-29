defmodule Beacon.RuntimeJS do
  # Runtime compilation and processing of JS files.
  @moduledoc false
  alias Beacon.Content

  require Logger

  # merge beacon js with host application dependencies js
  # similar to https://github.com/phoenixframework/phoenix_live_dashboard/blob/9140f56c34201237f0feeeff747528eed2795c0c/lib/phoenix/live_dashboard/controllers/assets.ex#L6-L11
  def build(site) do
    minify? = !(Code.ensure_loaded?(Mix.Project) and Mix.env() in [:test, :dev])

    validate_esbuild_install!()

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

    tmp_dir = tmp_dir!()

    {names, imports, paths} =
      Enum.reduce(Content.list_js_hooks(site), {[], [], []}, fn hook, {names, imports, paths} = acc ->
        # Write a file for each hook
        hook_js_path = Path.join(tmp_dir, hook.name <> ".js")
        File.write!(hook_js_path, hook.code)

        # Don't cleanup these files yet, we'll cleanup altogether at the end
        export =
          case get_export(hook, dir: tmp_dir, cleanup: false) do
            {:ok, export} when export in ["default", hook.name] -> export
            {:error, _error} -> nil
          end

        import_code =
          cond do
            export == "default" -> "import #{hook.name} from '#{hook_js_path}';"
            is_binary(export) -> "import { #{export} as #{hook.name} } from '#{hook_js_path}';"
            :else -> nil
          end

        if import_code do
          {[hook.name | names], [import_code | imports], [hook_js_path | paths]}
        else
          Logger.error("failed to import hook: #{inspect(hook)}")
          acc
        end
      end)

    # With all the valid data accumulated, write a single file for beacon hook imports
    # and load it into memory to be injected into the existing js deps
    hooks_js_path = Path.join(tmp_dir, "hooks.js")
    hooks = build_beacon_hooks(hooks_js_path, imports, names, minify?)

    js_deps =
      assets
      |> Enum.map(fn {app, asset} ->
        app
        |> Application.app_dir(["priv", "static", asset])
        |> File.read!()
        |> String.replace("//# sourceMappingURL=", "// ")
      end)

    # Everything we need is in memory now, so we can cleanup the files
    cleanup([hooks_js_path | paths], tmp_dir)

    IO.iodata_to_binary([hooks, "\n", js_deps])
  end

  defp build_beacon_hooks(path, imports, names, minify?) do
    hooks_code = [
      Enum.intersperse(imports, "\n"),
      "\n",
      "export default {\n",
      Enum.intersperse(names, ",\n"),
      "\n}"
    ]

    File.write!(path, hooks_code)

    args =
      ~w(#{path} --bundle --format=iife --target=es2016 --platform=browser) ++
        ~w(--global-name=BeaconHooks --log-level=error) ++
        if(minify?, do: ~w(--minify), else: [])

    cmd_opts = [cd: File.cwd!(), stderr_to_stdout: true]

    case System.cmd(Esbuild.bin_path(), args, cmd_opts) do
      {hooks, 0} -> hooks
      _ -> []
    end
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

  def get_export(hook, opts \\ []) do
    dir = Keyword.get(opts, :dir, tmp_dir!())
    cleanup? = Keyword.get(opts, :cleanup, true)
    hook_js_path = Path.join(dir, hook.name <> ".js")

    validate_esbuild_install!()

    if !File.exists?(hook_js_path), do: File.write!(hook_js_path, hook.code)

    with %{"outputs" => %{} = outputs} <- get_code_metadata(hook, dir),
         {_, %{"exports" => exports}} <- Enum.at(outputs, 0) do
      if cleanup?, do: cleanup([hook_js_path], dir)

      case exports do
        [] -> {:error, :no_export}
        [export] -> {:ok, export}
        exports when is_list(exports) -> {:error, :multiple_exports}
        _ -> {:error, :unknown}
      end
    else
      _ ->
        if cleanup?, do: cleanup([hook], dir)
        {:error, :esbuild_failed}
    end
  end

  defp validate_esbuild_install! do
    case Esbuild.bin_version() do
      {:ok, version} ->
        :ok

      :error ->
        raise Beacon.LoaderError, """
        esbuild binary not found or the installation is invalid.

        Execute the following command to install the binary used to process JS:

            mix esbuild.install

        """
    end
  end

  defp get_code_metadata(hook, dir) do
    hook_js_path = Path.join(dir, hook.name <> ".js")
    meta_json_path = Path.join(dir, hook.name <> ".json")
    meta_out_js_path = Path.join(dir, hook.name <> "_meta.js")
    cmd_opts = [cd: File.cwd!(), stderr_to_stdout: true]

    {_, 0} = System.cmd(Esbuild.bin_path(), ~w(#{hook_js_path} --metafile=#{meta_json_path} --outfile=#{meta_out_js_path}), cmd_opts)

    with {:ok, meta} <- File.read(meta_json_path),
         {:ok, meta} <- Jason.decode(meta) do
      cleanup([meta_json_path, meta_out_js_path])
      meta
    else
      _ ->
        cleanup([meta_json_path, meta_out_js_path])
        nil
    end
  end

  defp cleanup(files) when is_list(files) do
    Enum.each(files, &File.rm/1)
  end

  defp cleanup(files, dir) when is_list(files) do
    Enum.each(files, &File.rm/1)
    File.rmdir(dir)
  end
end
