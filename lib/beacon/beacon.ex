defmodule Beacon do
  @moduledoc """
  Beacon is Content Management System built on top of Phoenix LiveView that is focused on:

  * Fast rendering to boost SEO scores.
  * Reloading resources at runtime to avoid deployments.
  * Seamless integration with existing applications.

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
          [site: :my_site, endpoint: MyAppWeb.Endpoint]
        ],
        authorization_source: MyApp.AuthorizationPolicy

      # lib/my_app/application.ex
      def start(_type, _args) do
        children = [
          MyApp.Repo,
          {Phoenix.PubSub, name: MyApp.PubSub},
          {Beacon, Application.fetch_env!(:my_app, Beacon)},
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

  # FIXME: spec/doc/error handling
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
  def apply_mfa(module, function, args, failure_count \\ 0) when is_atom(module) and is_atom(function) and is_list(args) do
    apply(module, function, args)
  rescue
    e in UndefinedFunctionError ->
      case {failure_count, e} do
        {x, _} when x >= 10 ->
          mfa = Exception.format_mfa(module, function, length(args))
          Logger.debug("failed to call #{mfa} after #{failure_count} tries")
          reraise e, __STACKTRACE__

        {_, %UndefinedFunctionError{module: ^module, function: ^function}} ->
          mfa = Exception.format_mfa(module, function, length(args))
          Logger.debug("failed to call #{mfa} for the #{failure_count + 1} time, retrying...")
          :timer.sleep(100 * (failure_count * 2))
          apply_mfa(module, function, args, failure_count + 1)

        _ ->
          reraise e, __STACKTRACE__
      end

    _e in FunctionClauseError ->
      mfa = Exception.format_mfa(module, function, length(args))

      error_message = """
      could not call #{mfa} for the given path: #{inspect(List.flatten(args))}.

      Make sure you have created a page for this path.

      See Pages.create_page!/2 for more info.
      """

      reraise Beacon.LoaderError, [message: error_message], __STACKTRACE__

    e ->
      reraise e, __STACKTRACE__
  end

  @doc false
  # https://github.com/phoenixframework/phoenix_live_view/blob/8fedc6927fd937fe381553715e723754b3596a97/lib/phoenix_live_view/channel.ex#L435-L437
  def exported?(m, f, a) do
    function_exported?(m, f, a) || (Code.ensure_loaded?(m) && function_exported?(m, f, a))
  end
end
