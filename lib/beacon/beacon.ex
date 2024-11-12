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

    children = Enum.map(sites, &site_child_spec/1)
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp site_child_spec(opts) do
    config = Config.new(opts)
    Supervisor.child_spec({Beacon.SiteSupervisor, config}, id: config.site)
  end

  @doc """
  Boot a site executing the initial data population and resources loading.

  It will populate default content data and routes in the router table,
  enable PubSub events broadcasting, and load resource modules for layouts, pages, and others.

  This function is called by the site supervisor when a site is started and should not be called directly most of the times,
  but in some scenarions, you want to start Beacon and all related process like the Repo without actually booting the site,
  for example to seed initial data and in tests.

  In those scenarios you'd define the config `:mode` to `:manual` in your site configuration,
  execute everything you need and then call `Beacon.boot/1` to finally boot the site if necessary.

  Note that calling this function will update the config `:mode` to `:live` after the site gets booted,
  so all PubSub events necessary for Beacon to work properly are broadcasted as expected.
  """
  @spec boot(Beacon.Types.Site.t()) :: :ok
  def boot(site) when is_atom(site) do
    Beacon.Boot.init(site)

    # JUST TESTING
    config = Beacon.Config.fetch!(site)
    Beacon.RouterServer.handle_continue(:async_init, config)
    Beacon.Loader.handle_continue(:async_init, config)
    Beacon.Loader.reload_snippets_module(site)
    Beacon.Loader.reload_components_module(site)
    Beacon.Loader.reload_pages_modules(site)

    :ok
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

      reraise Beacon.RuntimeError,
              [message: apply_mfa_error_message(module, function, args, nil, context, error)],
              __STACKTRACE__
  end

  defp apply_mfa_error_message(module, function, args, reason, context, error) do
    mfa = Exception.format_mfa(module, function, length(args))
    summary = "failed to call #{mfa} with args: #{inspect(List.flatten(args))}"
    reason = if reason, do: "reason: #{reason}"
    context = if context, do: "context: #{inspect(context)}"
    error = if error, do: Exception.message(error)

    lines = for line <- [summary, reason, context, error], line != nil, do: line
    Enum.join(lines, "\n\n")
  end
end
