defmodule Beacon do
  @moduledoc """
  BeaconCMS
  """

  use Supervisor
  require Logger
  alias Beacon.Config

  @doc """
  Start `Beacon` and a supervisor for each site, which will load all layouts, pages, components, and so on.

  You must include the `Beacon` supervisor on each application that you want it loaded. For a single Phoenix application
  that would the in the `children` list on the file `lib/my_app/application.ex`. For Umbrella apps you can have
  multiple apps running Beacon, suppose your project has 3 apps: core (regular app), blog (phoenix app), and marketing (phoenix app)
  and you want to load one Beacon instance on each Phoenix app, so you would include `Beacon` in the list of `children` applications
  in both blog and marketing application with their own `:sites` configuration.

  Note that each Beacon instance may have multiple sites and each site loads in its own supervisor. That gives you the
  flexibility to plan your architecture from simple to complex environments.

  ## Options

  Each site in `:sites` may have its own configuration, see all available options at `Beacon.Config.new/1`.

  ## Examples

      # config.exs or runtime.exs
      config :my_app, Beacon,
        sites: [
          [site: :my_site, data_source: MyApp.BeaconDataSource]
        ],
        authorization_source: MyApp.AuthorizationPolicy

      # lib/my_app/application.ex
      def start(_type, _args) do
        children = [
          MyApp.Repo,
          {Phoenix.PubSub, name: MyApp.PubSub},
          {Beacon, Application.fetch_env!(:my_app, Beacon)}, # <- add before Endpoint
          MyAppWeb.Endpoint
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end


  """
  def start_link(opts) when is_list(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    sites =
      Keyword.get(opts, :sites) ||
        Logger.warning("Beacon will be started with no sites configured. See `Beacon.start_link/1` for more info.")

    # TODO: pubsub per site
    # children = [
    #   {Phoenix.PubSub, name: Beacon.PubSub}
    # ]

    authorization_source = Keyword.get(opts, :authorization_source)

    children =
      sites
      |> Enum.map(fn site_config -> assign_authorization_source(site_config, authorization_source) end)
      |> Enum.map(&site_child_spec/1)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp assign_authorization_source(site_config, nil), do: site_config

  defp assign_authorization_source(site_config, authorization_source) do
    Keyword.put_new(site_config, :authorization_source, authorization_source)
  end

  defp site_child_spec(opts) do
    config = Config.new(opts)
    Supervisor.child_spec({Beacon.SiteSupervisor, config}, id: config.site)
  end

  @tailwind_version "3.2.7"
  @doc false
  def tailwind_version, do: @tailwind_version

  @doc """
  Reload all resources for all running sites.
  """
  def reload_all_sites do
    Enum.map(Beacon.Registry.registered_sites(), &reload_site/1)
  end

  @doc """
  Reload all resources of `site`.
  """
  @spec reload_site(Beacon.Types.Site.t()) :: :ok
  defdelegate reload_site(site), to: Beacon.Loader

  @doc """
  Reload `page` and its dependencies.
  """
  @spec reload_page(Beacon.Pages.Page.t()) :: :ok
  defdelegate reload_page(page), to: Beacon.Loader

  @doc false
  def safe_code_check!(site, code) do
    if Beacon.Config.fetch!(site).safe_code_check do
      SafeCode.Validator.validate!(code, extra_function_validators: Beacon.Loader.SafeCodeImpl)
    end
  end

  def default_site_meta_tags do
    [
      %{"charset" => "utf-8"},
      %{"http-equiv" => "X-UA-Compatible", "content" => "IE=edge"},
      %{"name" => "viewport", "content" => "width=device-width, initial-scale=1"}
    ]
  end
end
