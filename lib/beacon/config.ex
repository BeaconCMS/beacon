defmodule Beacon.Config do
  @moduledoc """
  Configuration for sites.

  Following is a list of options that each site accepts:

  ## Options

    * `:site` (required) `t:site/0` - register your site supervisor with this key identifier,
      see the `t:site/0` type for more info.

    * `:data_source` (optional) `t:data_source/0` - a module that implements `Beacon.DataSource.Behaviour`,
      used to provide assigns to your site pages.

    * `css_compiler` (optional) `t:css_compiler/0` - a module that implements `Beacon.RuntimeCSS`,
      used to compile CSS for pages. Defaults to `Beacon.CSSCompiler`.

    * `:live_socket_path` (optional) `t:String.t/0` - path of a live socket where Beacon should connect to. Defaults to "/live".

  """

  alias Beacon.Registry

  @typedoc """
  An atom identifying your site.

  It has to be the same name used on `beacon_site` in your application router.
  """
  @type site :: atom()
  @type data_source :: module() | nil
  @type css_compiler :: module()

  @type option ::
          {:site, site()}
          | {:data_source, data_source()}
          | {:css_compiler, css_compiler()}
          | {:live_socket_path, String.t()}
          | {:safe_code_check, boolean()}

  @type t :: %__MODULE__{
          site: site(),
          data_source: data_source(),
          css_compiler: css_compiler(),
          live_socket_path: String.t(),
          safe_code_check: boolean()
        }

  defstruct site: nil,
            data_source: nil,
            css_compiler: Beacon.CSSCompiler,
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
