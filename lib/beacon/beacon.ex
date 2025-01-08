defmodule Beacon do
  @moduledoc """
  Beacon is a Content Management System for [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view).

  Key features include:

  * Rendering pages fast
  * Reloading content at runtime
  * Improved resource usage and scalability
  * Integration with existing Phoenix applications

  You can build virtually any type of website with Beacon, from a simple blog to a complex business site.

  The following are the main APIs provided by Beacon. You can find more information in the documentation for each of these modules:

  * `Beacon.Config` - configure your site(s)
  * `Beacon.Router` - mount site(s) into the router of your Phoenix application
  * `Beacon.Lifecycle` - inject custom logic into Beacon's lifecycle to change how pages are loaded, rendered, and more
  * `Beacon.Content` - manage content such as layouts, pages, page variants, snippets, etc.
  * `Beacon.MediaLibrary` - upload images, videos, and documents that can be used in your content
  * `Beacon.Test` - utilities for testing

  Get started with [your first site](https://hexdocs.pm/beacon/your-first-site.html) and check out the guides for more information.
  """

  @doc false
  use Supervisor
  require Logger

  @doc """
  Start `Beacon` and a supervisor for each site, which will load all layouts, pages, components, and so on.

  You must include the `Beacon` supervisor on each application that you want it loaded. For a single Phoenix application
  that would go in the `children` list on the file `lib/my_app/application.ex`. For Umbrella apps you can have
  multiple apps running Beacon, suppose your project has 3 apps: core (regular app), blog (phoenix app), and marketing (phoenix app)
  and you want to load one Beacon instance on each Phoenix app, so you would include `Beacon` in the list of `children` applications
  in both blog and marketing applications with their own `:sites` configuration.

  Note that each Beacon instance may have multiple sites and each site loads in its own supervisor. That gives you the
  flexibility to plan your architecture from simple to complex environments. For example, you can have a single site
  serving all pages in a single Phoenix application or you can create a new site to isolate a landing page for a marketing
  campaign that may receive too much traffic.

  See `Beacon.Router` and [Deployment Topologies](https://hexdocs.pm/beacon/deployment-topologies.html) for more information.

  ## Options

  Each site in `:sites` may have its own configuration, see all available options at `Beacon.Config.new/1`.

  ## Examples

      # runtime.exs
      config :beacon,
        my_site: [site: :my_site, repo: MyApp.Repo, endpoint: MyAppWeb.Endpoint, router: MyAppWeb.Router]

      # lib/my_app/application.ex
      def start(_type, _args) do
        children = [
          MyApp.Repo,
          {Phoenix.PubSub, name: MyApp.PubSub},
          MyAppWeb.Endpoint,
          {Beacon,
           [
             sites: [
               Application.fetch_env!(:beacon, :my_site)
             ]
           ]}
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end

  """
  def start_link(opts) when is_list(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  @impl true
  def init(opts) do
    sites = Keyword.get(opts, :sites, [])

    if sites == [] do
      Logger.warning("Beacon will start with no sites configured. See `Beacon.start_link/1` for more info.")
    end

    # TODO: pubsub per site?
    # children = [
    #   {Phoenix.PubSub, name: Beacon.PubSub}
    # ]

    :pg.start_link(:beacon_cluster)

    children =
      Enum.reduce(sites, [], fn opts, acc ->
        config = Beacon.Config.new(opts)

        # we only care about starting sites that are valid and reachable
        cond do
          Beacon.Config.env_test?() ->
            [site_child_spec(config) | acc]

          Beacon.Router.reachable?(config) ->
            [site_child_spec(config) | acc]

          :else ->
            Logger.warning(
              "site #{config.site} is not reachable on host #{config.endpoint.host()} and will not be started, see https://hexdocs.pm/beacon/troubleshoot.html"
            )

            acc
        end
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp site_child_spec(%Beacon.Config{} = config) do
    Supervisor.child_spec({Beacon.SiteSupervisor, config}, id: config.site)
  end

  @doc """
  Boot a site.

  It will restart the Site Supervisor if it's already running, otherwise it will start it in the main Beacon Supervisor.

  This function is not necessary to be called in most cases, as Beacon will automatically boot all sites when it starts,
  but in some cases where a site is started with the `:manual` mode, you may want to call this function to boot the site
  in the `:live` mode to activate resource loading and PubSub events broadcasting.

  Note that `:live` sites that are not reachable will not be started,
  see [deployment topologies](https://hexdocs.pm/beacon/deployment-topology.html) for more info.
  """
  @spec boot(Beacon.Config.t()) :: Supervisor.on_start_child() | {:error, :unreachable}
  def boot(%Beacon.Config{} = config) do
    if config.mode == :live && !Beacon.Router.reachable?(config) do
      Logger.error(
        "site #{config.site} is not reachable on host #{config.endpoint.host()} and will not be started, see https://hexdocs.pm/beacon/troubleshoot.html"
      )

      {:error, :unreachable}
    else
      site = config.site
      Supervisor.terminate_child(__MODULE__, site)
      Supervisor.delete_child(__MODULE__, site)
      spec = site_child_spec(config)
      Supervisor.start_child(__MODULE__, spec)
    end
  end

  @tailwind_version "3.4.4"
  @doc false
  def tailwind_version, do: @tailwind_version

  @doc false
  def safe_code_check!(site, code) do
    if Beacon.Config.fetch!(site).safe_code_check do
      SafeCode.Validator.validate!(code, extra_function_validators: Beacon.SafeCodeImpl)
    end
  end

  @doc false
  # This should always be used when calling dynamic modules
  # 1. Isolate function calls
  # 2. Enable Beacon's autoloading mechanism (ErrorHandler)
  # 3. Provide more meaningful error messages
  def apply_mfa(site, module, function, args, opts \\ [])
      when is_atom(site) and is_atom(module) and is_atom(function) and is_list(args) and is_list(opts) do
    Beacon.Loader.safe_apply_mfa(site, module, function, args, opts)
  end
end
