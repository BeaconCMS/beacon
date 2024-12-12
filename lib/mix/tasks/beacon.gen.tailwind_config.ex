defmodule Mix.Tasks.Beacon.Gen.TailwindConfig do
  use Igniter.Mix.Task

  @example "mix beacon.gen.tailwind_config"
  @shortdoc "Generates a new Tailwind config in the format expected by Beacon"

  @moduledoc """
  #{@shortdoc}

  It will also update your Phoenix project configuration to bundle the Tailwind configuration.

  See https://hexdocs.pm/beacon/tailwind-setup.html for more info.

  ## Example

  ```bash
  #{@example}
  ```

  """

  @doc false
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      example: @example,
      schema: [site: :string],
      aliases: [s: :site],
      required: [:site]
    }
  end

  @doc false
  def igniter(igniter) do
    options = igniter.args.options
    site = Keyword.fetch!(options, :site) |> String.to_atom()

    app_name = Igniter.Project.Application.app_name(igniter)
    {igniter, router} = Beacon.Igniter.select_router!(igniter)
    {igniter, endpoint} = Beacon.Igniter.select_endpoint!(igniter, router)

    igniter
    |> create_tailwind_config()
    |> add_esbuild_profile()
    |> add_endpoint_watcher(app_name, endpoint)
    |> add_esbuild_cmd_into_assets_build_alias()
    |> add_esbuild_cmd_into_assets_deploy_alias()
    |> add_tailwind_config_into_site_config(app_name, site)
  end

  defp create_tailwind_config(igniter) do
    Igniter.create_new_file(
      igniter,
      "assets/beacon.tailwind.config.js",
      """
      // Tailwind config for Beacon Sites
      //
      // See the Tailwind configuration guide for advanced usage
      // https://tailwindcss.com/docs/configuration
      //
      // And Beacon's Tailwind Setup guide for more info
      // https://hexdocs.pm/beacon/tailwind-setup.html

      const plugin = require("tailwindcss/plugin")

      export default {
        content: [],
        theme: {
          extend: {},
        },
        plugins: [
          require("@tailwindcss/forms"),
          require("@tailwindcss/typography"),

          // Allows prefixing tailwind classes with LiveView classes to add rules
          // only when LiveView classes are applied, for example:
          //
          //     <div class="phx-click-loading:animate-ping">
          //
          plugin(({ addVariant }) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
          plugin(({ addVariant }) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
          plugin(({ addVariant }) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),
        ],
      }
      """,
      on_exists: :warning
    )
  end

  defp add_esbuild_profile(igniter) do
    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      :esbuild,
      [:beacon_tailwind_config],
      {:code,
       Sourceror.parse_string!("""
         [
           args: ~w(beacon.tailwind.config.js --bundle --format=esm --target=es2020 --outfile=../priv/beacon.tailwind.config.bundle.js),
           cd: Path.expand("../assets", __DIR__),
           env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
         ]
       """)}
    )
  end

  defp add_endpoint_watcher(igniter, app_name, endpoint) do
    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      app_name,
      [endpoint, :watchers],
      [],
      updater: fn zipper ->
        Igniter.Code.Keyword.put_in_keyword(
          zipper,
          [:beacon_tailwind_config],
          Sourceror.parse_string!("{Esbuild, :install_and_run, [:beacon_tailwind_config, ~w(--watch)]}")
        )
      end
    )
  end

  defp add_esbuild_cmd_into_assets_build_alias(igniter) do
    Igniter.Project.TaskAliases.add_alias(igniter, "assets.build", "esbuild beacon_tailwind_config", if_exists: :append)
  end

  defp add_esbuild_cmd_into_assets_deploy_alias(igniter) do
    Igniter.Project.TaskAliases.add_alias(igniter, "assets.deploy", "esbuild beacon_tailwind_config --minify", if_exists: :append)
  end

  defp add_tailwind_config_into_site_config(igniter, app_name, site) do
    Igniter.Project.Config.configure(
      igniter,
      "runtime.exs",
      :beacon,
      [site],
      [],
      updater: fn zipper ->
        Igniter.Code.Keyword.put_in_keyword(
          zipper,
          [:tailwind_config],
          Sourceror.parse_string!(~s|Path.join(Application.app_dir(:#{app_name}, "priv"), "beacon.tailwind.config.bundle.js")|)
        )
      end
    )
  end
end
