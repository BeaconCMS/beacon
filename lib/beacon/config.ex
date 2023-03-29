defmodule Beacon.Config do
  @moduledoc """
  Configuration for sites.

  Following is a list of options that each site accepts:

  ## Options

    * `:site` (required) `t:site/0` - register your site supervisor with this key identifier,
      see the `t:site/0` type for more info.

    * `:data_source` (optional) `t:data_source/0` - a module that implements `Beacon.DataSource.Behaviour`,
      used to provide assigns to your site pages.

    * `:authorization_source` (optional) `t:authorization_source/0` - a module that implements `Beacon.Authorization.Behaviour`,
      used to provide authorization rules for the admin backend. Defaults to `Beacon.Authorization.DefaultPolicy` and note this config can't be `nil`.

    * `css_compiler` (optional) `t:css_compiler/0` - a module that implements `Beacon.RuntimeCSS`,
      used to compile CSS for pages. Defaults to `Beacon.TailwindCompiler`.

    * `:tailwind_config` (optional) - path to a custom tailwind config, defaults to `Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex")`.
      Note that this config file must include `<%= @beacon_content %>` in the `content` section, see `Beacon.TailwindCompiler` for more info.

    * `:live_socket_path` (optional) `t:String.t/0` - path of a live socket where Beacon should connect to. Defaults to "/live".

  """

  alias Beacon.Registry

  @typedoc """
  An atom identifying your site.

  It has to be the same name used on `beacon_site` in your application router.
  """
  @type site :: atom()
  @type data_source :: module() | nil
  @type authorization_source :: module()
  @type css_compiler :: module()
  @type tailwind_config :: Path.t()

  @type option ::
          {:site, site()}
          | {:data_source, data_source()}
          | {:authorization_source, authorization_source()}
          | {:css_compiler, css_compiler()}
          | {:tailwind_config, tailwind_config()}
          | {:live_socket_path, String.t()}
          | {:safe_code_check, boolean()}

  @type t :: %__MODULE__{
          site: site(),
          data_source: data_source(),
          authorization_source: authorization_source(),
          css_compiler: css_compiler(),
          tailwind_config: tailwind_config(),
          live_socket_path: String.t(),
          safe_code_check: boolean()
        }

  defstruct site: nil,
            data_source: nil,
            authorization_source: Beacon.Authorization.DefaultPolicy,
            css_compiler: Beacon.TailwindCompiler,
            tailwind_config: Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex"),
            live_socket_path: "/live",
            safe_code_check: false

  @doc """
  Build a new `%Beacon.Config{}` instance, used to hold all the configuration for each site.

  See the moduledoc for possible options.
  """
  @spec new([option]) :: t()
  def new(opts) do
    # TODO: validate config opts
    struct!(__MODULE__, opts)
  end

  @spec fetch!(site()) :: t()
  def fetch!(site) do
    Registry.config!(site)
  end
end
