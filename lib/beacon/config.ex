defmodule Beacon.Config do
  @moduledoc """
  Configuration for sites.

  See `new/1` for options and examples.

  """

  alias Beacon.Registry

  @typedoc """
  An atom identifying your site.

  It has to be the same name used on `beacon_site` in your application router.
  """
  @type site :: Beacon.Types.Site.t()
  @type data_source :: module() | nil
  @type authorization_source :: module()
  @type css_compiler :: module()
  @type tailwind_config :: Path.t()

  @typedoc """
  Register a format to handle loading and rendering templates.

  Beacon provides two formats built-in: HEEx and Markdown,
  that can be replaced by registering a new format with the same name.

  ## Example

      {
        "markdown",
        "My Custom Markdown",
        [
          load: [
            convert_to_html: fn template, _metadata -> MyEngine.parse(template) end,
            safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
            compile_heex: &Beacon.Template.HEEx.compile/2
          ],
          render: [
            eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
          ]
        ]
      }

  Each step may return one of the following:

  * `{:cont, template}` - to keep processing the next step.
  * `{:halt, template}` - to return early, stopping the pipeline with success.
  * `{:halt, exception}` - to raise and stop execution.

  Note that `:load` doesn't necessarily expect the output to be compiled, it can return a binary for example,
  but `:render` does expect the output to be a `%Phoenix.LiveView.Rendered{}` struct.

  """
  @type template_format :: {identifier :: String.t(), description :: String.t(), [template_stage()]}

  @typedoc """
  Stages for a registered template format.

  Two are expected:

  **Load** is the stage of fetching the template from the database and loading it into ETS. The steps define here run in between those.
  The formats HEEx and Markdown provded built-in by Beacon will take care of checking if the the template is secure, converting to proper HTML,
  and compiling it down to a complete AST that can be rendered afterwards.

  **Render** runs in the `render/1` callback of LiveView, it receives the `assigns` plus metadata of the current request to generate
  a `%Phoenix.LiveView.Rendered{}` struct at the end of the lifecycle.

  """
  @type template_stage ::
          {:load, [template_load_step()]}
          | {:render, [template_render_step()]}

  @type template_load_step ::
          {identifier :: atom(),
           fun ::
             (Beacon.Template.t(), Beacon.Template.LoadMetadata.t() ->
                {:cont, Beacon.Template.t()} | {:halt, Beacon.Template.t()} | {:halt, Exception.t()})}

  @type template_render_step ::
          {identifier :: atom(),
           fun ::
             (Beacon.Template.t(), Beacon.Template.RenderMetadata.t() ->
                {:cont, Beacon.Template.t()} | {:halt, Beacon.Template.t()} | {:halt, Exception.t()})}

  @type publish_page_step ::
          {identifier :: atom(), fun :: (Beacon.Pages.Page.t() -> {:cont, Beacon.Pages.Page.t()} | {:halt, Exception.t()})}

  @typedoc """
  Lifecycle configuration.

  See `Beacon.Lifecycle` for more info on each hook and `new/1` for examples.

  """
  @type lifecycle_option ::
          {:template_format, [template_format()]}
          | {:publish_page, [publish_page_step()]}

  @type t :: %__MODULE__{
          site: site(),
          data_source: data_source(),
          authorization_source: authorization_source(),
          css_compiler: css_compiler(),
          tailwind_config: tailwind_config(),
          live_socket_path: String.t(),
          safe_code_check: boolean(),
          lifecycle: [lifecycle_option()]
        }

  defstruct site: nil,
            data_source: nil,
            authorization_source: Beacon.Authorization.DefaultPolicy,
            css_compiler: Beacon.TailwindCompiler,
            tailwind_config: Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex"),
            live_socket_path: "/live",
            # TODO: change safe_code_check to true when it's ready to parse complex codes
            safe_code_check: false,
            lifecycle: [
              template: [
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
              ],
              publish_page: []
            ]

  @type option ::
          {:site, site()}
          | {:data_source, data_source()}
          | {:authorization_source, authorization_source()}
          | {:css_compiler, css_compiler()}
          | {:tailwind_config, tailwind_config()}
          | {:live_socket_path, String.t()}
          | {:safe_code_check, boolean()}
          | {:lifecycle, [lifecycle_option()]}

  @doc """
  Build a new `%Beacon.Config{}` instance used to hold the entire configuration for each site.

  ## Options

    * `:site` - `t:Beacon.Types.Site.t/0` (required)\n
    Identifier used internally to register and fetch a site.

    * `:data_source` - `t:data_source/0` (optional)\n
    A module that implements `Beacon.DataSource.Behaviour`, used to provide assigns to pages.

    * `:authorization_source` - `t:authorization_source/0` (optional)\n
    A module that implements `Beacon.Authorization.Behaviour`, used to provide authorization rules for the admin backend. Note this config can't be `nil`.
    Defaults to `Beacon.Authorization.DefaultPolicy`.

    * `css_compiler` - `t:css_compiler/0` (optional)\n
    A module that implements `Beacon.RuntimeCSS`, used to compile CSS for pages.
   Defaults to `Beacon.TailwindCompiler`.

    * `:tailwind_config` - `t:tailwind_config/0` (optional)\n
    Path to a custom tailwind config. Note that this config file must include `<%= @beacon_content %>` in the `content` section, see `Beacon.TailwindCompiler` for more info.
    Defaults to `Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex")`.

    * `:live_socket_path` - `t:String.t/0` (optional)\n
    Path of a live socket where Beacon should connect to.
    Defaults to `"/live"`.

    * `:safe_code_check` - `t:boolean/0` (optional)\n
    Enable or disable safe Elixir code check by https://github.com/TheFirstAvenger/safe_code
    Defaults to `false`.

    * `lifecycle` - list of `t:lifecycle_option/0` (optional)\n
    Register steps in Beacon lifecycle.

  ## Example

      [
        site: :my_site,
        data_source: MyApp.SiteDataSource,
        authorization_source: MyApp.SiteAuthnPolicy,
        css_compiler: Beacon.TailwindCompiler,
        tailwind_config: Path.join(Application.app_dir(:my_app, "priv"), "tailwind.config.js.eex"),
        lifecycle: [
          template: [
            {
              "custom_format",
              "My Custom Format",
              load: [
                validate: fn template, _metadata -> MyEngine.validate(template) end
              ],
              render: [
                assigns: fn template, %{assigns: assigns} -> MyEngine.parse(template, assigns) end,
                compile: fn template, _metadata -> MyEngine.compile(template),
                eval: &Beacon.Template.HEEx.eval_ast/2
              ]
            }
          ],
          publish_page: [
            notify_admin: fn page -> {:cont, MyApp.send_email(page) end
          ]
        ]
      ]

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
