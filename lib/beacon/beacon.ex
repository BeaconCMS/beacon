defmodule Beacon do
  @moduledoc """
  Beacon is a Content Management System built on top of Phoenix LiveView, focused on:

  * Rendering pages fast.
  * Reloading content at runtime.
  * Reduced resources usage and scalability.
  * Integration with existing Phoenix applications.

  You can build virtually any type of website with Beacon, from a simple blog to a complex business site.

  Following are the main APIs provided by Beacon. You can find out more information on each module.

  * `Beacon.Config` - configuration of sites.
  * `Beacon.Lifecycle` - inject custom logic into Beacon lifecycle to change how pages are loaded an rendred, and more.
  * `Beacon.Content` - manage content as layouts, pages, page variants, snippets, and more.
  * `Beacon.MediaLibrary` - upload images, videos, and documents that can be used in your content.
  * `Beacon.Authorization` - define permissions to limit access to content and features, also used on Beacon LiveAdmin.

  Follow along with [guides](https://github.com/BeaconCMS/beacon/tree/main/guides) to get started now and build your first site.

  """

  use Supervisor
  require Logger
  alias Beacon.Config

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
  campaing that may receive too much traffic.

  ## Options

  Each site in `:sites` may have its own configuration, see all available options at `Beacon.Config.new/1`.

  ## Examples

      # config.exs or runtime.exs
      config :my_app, Beacon,
        sites: [
          [site: :my_site, endpoint: MyAppWeb.Endpoint]
        ],
        authorization_source: MyApp.AuthorizationPolicy

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

  @doc """
  Boot a site executing the initial data population and resources loading.

  It will populate default content data and routes in the router table,
  enable PubSub events broadcasting, and load resource modules for layouts, pages, and others.

  This function is called by the site supervisor when a site is started and should not be called directly most of the times,
  but in some scenarions, you want to start Beacon and all related process like the Repo without actually booting the site,
  for example to seed initial data and in tests.

  In those scenarios you'd define the config `skip_boot?` to `true` in your site configuration,
  execute everything you need and then call `Beacon.boot/1` to finally boot the site if necessary.

  Note that calling this function will update the running `site` config `skip_boot?` to `false` automatically after the site gets booted,
  so all PubSub events necessary for Beacon to work properly are broadcasted as expected.
  """
  @spec boot(Beacon.Types.Site.t()) :: :ok
  def boot(site) do
    Beacon.Boot.do_init(Config.fetch!(site))
    Beacon.Config.update_value(site, :skip_boot?, false)
    :ok
  end

  @tailwind_version "3.3.1"
  @doc false
  def tailwind_version, do: @tailwind_version

  @doc false
  def safe_code_check!(site, code) do
    if Beacon.Config.fetch!(site).safe_code_check do
      SafeCode.Validator.validate!(code, extra_function_validators: Beacon.SafeCodeImpl)
    end
  end

  @doc false
  # Provides a safer `apply` for cases where `module` is being recompiled,
  # and also raises with more context about the called mfa.
  #
  # This should always be used when calling dynamic modules
  def apply_mfa(module, function, args, opts \\ []) when is_atom(module) and is_atom(function) and is_list(args) and is_list(opts) do
    context = Keyword.get(opts, :context, nil)
    do_apply_mfa(module, function, args, 0, context)
  end

  defp do_apply_mfa(module, function, args, failure_count, context) when is_atom(module) and is_atom(function) and is_list(args) do
    if :erlang.module_loaded(module) do
      apply(module, function, args)
    else
      raise Beacon.RuntimeError, message: apply_mfa_error_message(module, function, args, "module is not loaded", context)
    end
  rescue
    e in UndefinedFunctionError ->
      case {failure_count, e} do
        {failure_count, _} when failure_count >= 10 ->
          mfa = Exception.format_mfa(module, function, length(args))
          Logger.debug("failed to call #{mfa} after #{failure_count} tries")
          reraise Beacon.RuntimeError, [message: apply_mfa_error_message(module, function, args, "exceeded retries", context)], __STACKTRACE__

        {_, %UndefinedFunctionError{module: ^module, function: ^function}} ->
          mfa = Exception.format_mfa(module, function, length(args))
          Logger.debug("failed to call #{mfa} for the #{failure_count + 1} time, retrying...")
          :timer.sleep(100 * (failure_count * 2))
          do_apply_mfa(module, function, args, failure_count + 1, context)

        {_, e} ->
          reraise Beacon.RuntimeError,
                  [message: apply_mfa_error_message(module, function, args, "runtime error - #{inspect(e)}", context)],
                  __STACKTRACE__
      end

    e ->
      reraise Beacon.RuntimeError, [message: apply_mfa_error_message(module, function, args, inspect(e), context)], __STACKTRACE__
  end

  defp apply_mfa_error_message(module, function, args, reason, context) do
    mfa = Exception.format_mfa(module, function, length(args))

    context =
      case context do
        nil -> ""
        _ -> "context: #{inspect(context)}"
      end

    """
    failed to call #{mfa} with args: #{inspect(List.flatten(args))}

    reason: #{reason}

    #{context}

    Make sure you have created a page for this path.
    See Pages.create_page!/2 for more info.
    """
  end

  @doc false
  # https://github.com/phoenixframework/phoenix_live_view/blob/8fedc6927fd937fe381553715e723754b3596a97/lib/phoenix_live_view/channel.ex#L435-L437
  def exported?(m, f, a) do
    function_exported?(m, f, a) || (Code.ensure_loaded?(m) && function_exported?(m, f, a))
  end
end
