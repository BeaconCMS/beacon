defmodule Beacon.SiteSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: Beacon.Registry.via({:site, config.site}, config))
  end

  @impl true
  def init(config) do
    children = [
      {Beacon.Content, config},
      {Beacon.RouterServer, {config, skip_seed: Beacon.Config.env_test?()}},
      {DynamicSupervisor,
       name: Beacon.Registry.via({config.site, Beacon.LoaderSupervisor}), strategy: :one_for_one, max_restarts: 10, max_seconds: 30},
      {Beacon.Loader, config}
    ]

    children =
      if Beacon.Config.env_test?() do
        children ++
          [
            # reload only the components module because it gets imported into other modules, to avoid compilation issues
            task_child_spec(:reload_components_module, fn -> Beacon.Loader.reload_components_module(config.site) end)
          ]
      else
        children ++
          [
            task_child_spec(:populate_default_components, fn -> Beacon.Loader.populate_default_components(config.site) end),
            task_child_spec(:populate_default_layouts, fn -> Beacon.Loader.populate_default_layouts(config.site) end),
            task_child_spec(:populate_default_error_pages, fn -> Beacon.Loader.populate_default_error_pages(config.site) end),
            task_child_spec(:reload_runtime_js, fn -> Beacon.Loader.reload_runtime_js(config.site) end),
            task_child_spec(:reload_runtime_css, fn -> Beacon.Loader.reload_runtime_css(config.site) end),
            task_child_spec(:reload_stylesheet_module, fn -> Beacon.Loader.reload_stylesheet_module(config.site) end),
            task_child_spec(:reload_snippets_module, fn -> Beacon.Loader.reload_snippets_module(config.site) end),
            task_child_spec(:reload_components_module, fn -> Beacon.Loader.reload_components_module(config.site) end),
            task_child_spec(:reload_live_data_module, fn -> Beacon.Loader.reload_live_data_module(config.site) end),
            task_child_spec(:reload_layouts_modules, fn -> Beacon.Loader.reload_layouts_modules(config.site) end),
            task_child_spec(:reload_error_page_module, fn -> Beacon.Loader.reload_error_page_module(config.site) end),
            task_child_spec(:reload_recent_pages_modules, fn -> Beacon.Loader.reload_pages_modules(config.site, per_page: 20) end)
          ]
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp task_child_spec(id, fun) do
    Supervisor.child_spec({Task, fun}, id: {Task, id})
  end
end
