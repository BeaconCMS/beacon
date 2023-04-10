defmodule Beacon.Config do
  @moduledoc """
  Configuration for sites.

  Each site holds a `%Beacon.Config{}` struct in registry to define its behavior. Following is a summary of each parameter:

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

    * `:safe_code_check` (optional) `t:boolean/0` - enable or disable safe Elixir code check by https://github.com/TheFirstAvenger/safe_code

    * `:template_formats` (optional) `t:template_formats/0` - register template formats and its lifecycle.

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

  @typedoc """
  Registered formats to handle templates.

  Beacon provides two formats built-in: HEEx and Markdown.

  ## Example

      template_formats: [
        {
          "markdown",
          "My Custom Markdown",
          [
            load: [
              convert_to_html: fn template, _metadata ->
                MyEngine.parse(template)
              end,
              safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
              compile_heex: &Beacon.Template.HEEx.compile/2
            ],
            render: [
              eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
            ]
          ]
        }
      ]

  Note that `:load` doesn't necessarily expect the output to be compiled, it can return a binary for example,
  but `:render` does expect the output to be a `%Phoenix.LiveView.Rendered{}` struct.
  """
  @type template_formats :: [{identifier :: template_identifier(), description :: String.t(), lifecycle: template_lifecycle()}]

  @type option ::
          {:site, site()}
          | {:data_source, data_source()}
          | {:authorization_source, authorization_source()}
          | {:css_compiler, css_compiler()}
          | {:tailwind_config, tailwind_config()}
          | {:live_socket_path, String.t()}
          | {:safe_code_check, boolean()}
          | {:template_formats, template_formats()}

  @typedoc """
  The indentifier used internally to fetch templates, for eg: `"heex"`
  """
  @type template_identifier :: String.t()

  @typedoc """
  Steps of the template lifecycle. A step may run in either one of the two stages: load or render.

  **Load** is the stage of fetching the template from the database and loading it into ETS. The steps define here run in between those.
  The formats HEEx and Markdown provded built-in by Beacon will take care of checking if the the template is secure, converting to proper HTML,
  and compiling it down to a complete AST that can be rendered afterwards.

  **Render** runs in the `render/1` callback of LiveView, it receives the `assigns` plus metadata of the current request to generate
  a `%Phoenix.LiveView.Rendered{}` struct at the end of the lifecycle.
  """
  @type template_lifecycle :: list()

  @type t :: %__MODULE__{
          site: site(),
          data_source: data_source(),
          authorization_source: authorization_source(),
          css_compiler: css_compiler(),
          tailwind_config: tailwind_config(),
          live_socket_path: String.t(),
          safe_code_check: boolean(),
          template_formats: [{identifier :: template_identifier(), description :: String.t(), template_lifecycle :: template_lifecycle()}]
        }

  defstruct site: nil,
            data_source: nil,
            authorization_source: Beacon.Authorization.DefaultPolicy,
            css_compiler: Beacon.TailwindCompiler,
            tailwind_config: Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex"),
            live_socket_path: "/live",
            # TODO: change safe_code_check to true when it's ready to parse complex codes
            safe_code_check: false,
            template_formats: [
              {
                "heex",
                "HEEx (HTML)",
                load: [
                  safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
                  compile_heex: &Beacon.Template.HEEx.compile/2
                ],
                render: [
                  eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
                ]
              },
              {
                "markdown",
                "Markdown (GitHub Flavored)",
                [
                  load: [
                    convert_to_html: &Beacon.Template.Markdown.convert_to_html/2,
                    safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
                    compile_heex: &Beacon.Template.HEEx.compile/2
                  ],
                  render: [
                    eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
                  ]
                ]
              }
            ]

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
