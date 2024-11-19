defmodule Beacon do
  @moduledoc """
  Beacon is a Content Management System for [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view).

  * Rendering pages fast.
  * Reloading content at runtime.
  * Reduced resources usage and scalability.
  * Integration with existing Phoenix applications.

  You can build virtually any type of website with Beacon, from a simple blog to a complex business site.

  Following are the main APIs provided by Beacon. You can find out more information on the module documentation of each one of those modules:

  * `Beacon.Config` - configuration of sites.
  * `Beacon.Router` - mount one or more sites into the router of your Phoenix application.
  * `Beacon.Lifecycle` - inject custom logic into Beacon lifecycle to change how pages are loaded an rendred, and more.
  * `Beacon.Content` - manage content as layouts, pages, page variants, snippets, and more.
  * `Beacon.MediaLibrary` - upload images, videos, and documents that can be used in your content.
  * `Beacon.Test` - testings utilities.

  Get started with [your first site](https://hexdocs.pm/beacon/your-first-site.html) and check out the guides for more information.

  """

  @doc false
  use Supervisor

  alias Beacon.Config

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

  ## Options

  Each site in `:sites` may have its own configuration, see all available options at `Beacon.Config.new/1`.

  ## Examples

      # config.exs or runtime.exs
      config :my_app, Beacon,
        sites: [
          [site: :my_site, endpoint: MyAppWeb.Endpoint]
        ]

      # lib/my_app/application.ex
      def start(_type, _args) do
        children = [
          MyApp.Repo,
          {Phoenix.PubSub, name: MyApp.PubSub},
          {Beacon, Application.fetch_env!(:my_app, Beacon)}, # <- added Beacon here
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

    # TODO: pubsub per site?
    # children = [
    #   {Phoenix.PubSub, name: Beacon.PubSub}
    # ]

    :pg.start_link(:beacon_cluster)

    children =
      sites
      |> Enum.map(&site_child_spec/1)
      |> Enum.reject(&is_nil/1)

    Supervisor.init(children, strategy: :one_for_one)
  end

  # we only care about starting sites that are valid and reachable
  defp site_child_spec(%Beacon.Config{} = config) do
    if Beacon.Router.reachable?(config) do
      Supervisor.child_spec({Beacon.SiteSupervisor, config}, id: config.site)
    else
      %{site: site, endpoint: endpoint, router: router} = config
      prefix = router.__beacon_scoped_prefix_for_site__(site)
      Logger.warning("site #{site} is not reachable and will not be started, see https://hexdocs.pm/beacon/troubleshoot.html")
      nil
    end
  end

  defp site_child_spec(opts) do
    opts
    |> Config.new()
    |> site_child_spec()
  end

  @doc """
  Boot a site.

  It will restart the Site Supervisor if it's already running, otherwise it will start it in the main Beacon Supervisor.

  This function is not necessary to be called in most cases, as Beacon will automatically boot all sites when it starts,
  but in some cases where a site is started with the `:manual` mode, you may want to call this function to boot the site
  in the `:live` mode to active resource loading and PubSub events broadcasting.
  """
  @spec boot(Beacon.Config.t()) :: Supervisor.on_start_child() | :error
  def boot(%Beacon.Config{} = config) do
    site = config.site
    spec = site_child_spec(config)
    Supervisor.terminate_child(__MODULE__, site)
    Supervisor.delete_child(__MODULE__, site)
    Supervisor.start_child(__MODULE__, spec)
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
  # This should always be used when calling dynamic modules to provide better error messages
  def apply_mfa(module, function, args, opts \\ []) when is_atom(module) and is_atom(function) and is_list(args) and is_list(opts) do
    apply(module, function, args)
  rescue
    error ->
      context = Keyword.get(opts, :context, nil)
      reraise Beacon.InvokeError, [error: error, args: args, context: context], __STACKTRACE__
  end
end
