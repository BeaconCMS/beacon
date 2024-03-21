defmodule Beacon.Boot do
  @moduledoc false

  # Initialized all the required data and components for site
  # so it doesn't crash on initial requests nor display unstyled pages or error pages.

  use GenServer, restart: :transient
  require Logger

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  if Beacon.Config.env_test?() do
    def init(config) do
      # Reloads only the components module because it gets imported into other modules, to avoid compilation issues
      Beacon.Loader.reload_components_module(config.site)
      :ignore
    end
  else
    def init(config) do
      boot = fn ->
        task_supervisor = task_supervisor(config.site)

        populate = [
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.populate_default_components(config.site) end),
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.populate_default_layouts(config.site) end),
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.populate_default_error_pages(config.site) end)
        ]

        Task.await_many(populate, :timer.minutes(1))

        assets = [
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_runtime_js(config.site) end),
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_runtime_css(config.site) end)
        ]

        # TODO: revisit this timeout after we upgrade to Tailwind v4
        Task.await_many(assets, :timer.minutes(5))

        # Layouts and pages depend on the components module so we need to load it first
        Beacon.Loader.reload_components_module(config.site)

        modules = [
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_stylesheet_module(config.site) end),
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_snippets_module(config.site) end),
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_live_data_module(config.site) end),
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_layouts_modules(config.site) end),
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_error_page_module(config.site) end),
          Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_pages_modules(config.site, per_page: 20) end)
          # TODO: load main pages (order_by: path, per_page: 10) to avoid SEO issues
        ]

        Task.await_many(modules, :timer.minutes(2))
      end

      {time, _} = :timer.tc(boot, :seconds)
      Logger.info("Finished booting site #{config.site} in #{time} seconds")

      :ignore
    end

    defp task_supervisor(site) do
      Beacon.Registry.via({site, TaskSupervisor})
    end
  end
end
