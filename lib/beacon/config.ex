defmodule Beacon.Config do
  @moduledoc """
  Configuration for sites.

  See `new/1` for options and examples.

  """

  alias Beacon.Registry

  @typedoc """
  A module that implements `Beacon.DataSource.Behaviour`, used to provide `@assigns` to pages.
  """
  @type data_source :: module() | nil

  @typedoc """
  A module that implements `Beacon.Authorization.Behaviour`, used to provide authorization rules for the admin backend.
  """
  @type authorization_source :: module()

  @typedoc """
  A module that implements `Beacon.RuntimeCSS`, used to compile CSS for pages.
  """
  @type css_compiler :: module()

  @typedoc """
  Path to a custom tailwind config. Note that this config file must include `<%= @beacon_content %>` in the `content` section, see `Beacon.TailwindCompiler` for more info.
  """
  @type tailwind_config :: Path.t()

  @typedoc """
  Path of a live socket where Beacon should connect to.
  """
  @type live_socket_path :: String.t()

  @typedoc """
  Check safety of Elixir code using https://github.com/TheFirstAvenger/safe_code
  """
  @type safe_code_check :: boolean()

  @typedoc """
  Register formats to handle templates, eg: `[{:heex, "HEEx (HTML)"}]`.

  Beacon provides two formats built-in, HEEx and Markdown, but you can register your own
  as long as you also implement the life-cycle stages `:load_template` and `:render_template`.

  The description is used on user interfaces as Beacon Admin.
  """
  @type template_formats :: [{format :: atom(), description :: String.t()}]

  @typedoc """
  Attach steps into Beacon's internal life-cycle stages to inject custom functionality.
  """
  @type lifecycle :: [lifecycle_stage()]

  @typedoc """
  Life-cycle stages.
  """
  @type lifecycle_stage ::
          {:load_template,
           [
             {format :: String.t(),
              [
                {identifier :: atom(),
                 fun ::
                   (Beacon.Template.t(), Beacon.Template.LoadMetadata.t() ->
                      {:cont, Beacon.Template.t()} | {:halt, Beacon.Template.t()} | {:halt, Exception.t()})}
              ]}
           ]}
          | {:render_template,
             [
               {format :: String.t(),
                [
                  {identifier :: atom(),
                   fun ::
                     (Beacon.Template.t(), Beacon.Template.RenderMetadata.t() ->
                        {:cont, Beacon.Template.t()} | {:halt, Beacon.Template.t()} | {:halt, Exception.t()})}
                ]}
             ]}
          | {:publish_page, [{identifier :: atom(), fun :: (Beacon.Pages.Page.t() -> {:cont, Beacon.Pages.Page.t()} | {:halt, Exception.t()})}]}
          | {:create_page, [{identifier :: atom(), fun :: (Beacon.Pages.Page.t() -> {:cont, Beacon.Pages.Page.t()} | {:halt, Exception.t()})}]}
          | {:update_page, [{identifier :: atom(), fun :: (Beacon.Pages.Page.t() -> {:cont, Beacon.Pages.Page.t()} | {:halt, Exception.t()})}]}

  @typedoc """
  Add extra fields to pages.
  """
  @type extra_page_fields :: [module()]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          data_source: data_source(),
          authorization_source: authorization_source(),
          css_compiler: css_compiler(),
          tailwind_config: tailwind_config(),
          live_socket_path: live_socket_path(),
          safe_code_check: safe_code_check(),
          template_formats: template_formats(),
          lifecycle: lifecycle(),
          extra_page_fields: extra_page_fields()
        }

  @default_load_template [
    {:heex,
     [
       safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
       compile_heex: &Beacon.Template.HEEx.compile/2
     ]},
    {:markdown,
     [
       convert_to_html: &Beacon.Template.Markdown.convert_to_html/2,
       safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
       compile_heex: &Beacon.Template.HEEx.compile/2
     ]}
  ]

  @default_render_template [
    {:heex,
     [
       eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
     ]},
    {:markdown,
     [
       eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
     ]}
  ]

  defstruct site: nil,
            data_source: nil,
            authorization_source: Beacon.Authorization.DefaultPolicy,
            css_compiler: Beacon.TailwindCompiler,
            tailwind_config: Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex"),
            live_socket_path: "/live",
            # TODO: change safe_code_check to true when it's ready to parse complex codes
            safe_code_check: false,
            template_formats: [
              {:heex, "HEEx (HTML)"},
              {:markdown, "Markdown (GitHub Flavored version)"}
            ],
            lifecycle: [
              load_template: @default_load_template,
              render_template: @default_render_template,
              publish_page: [],
              create_page: [],
              update_page: []
            ],
            extra_page_fields: []

  @type option ::
          {:site, Beacon.Types.Site.t()}
          | {:data_source, data_source()}
          | {:authorization_source, authorization_source()}
          | {:css_compiler, css_compiler()}
          | {:tailwind_config, tailwind_config()}
          | {:live_socket_path, live_socket_path()}
          | {:safe_code_check, safe_code_check()}
          | {:template_formats, template_formats()}
          | {:lifecycle, lifecycle()}
          | {:extra_page_fields, extra_page_fields()}

  @doc """
  Build a new `%Beacon.Config{}` instance to hold the entire configuration for each site.

  ## Options

    * `:site` - `t:Beacon.Types.Site.t/0` (required)

    * `:data_source` - `t:data_source/0` (optional)

    * `:authorization_source` - `t:authorization_source/0` (optional).
    Note this config can't be `nil`. Defaults to `Beacon.Authorization.DefaultPolicy`.

    * `css_compiler` - `t:css_compiler/0` (optional).
   Defaults to `Beacon.TailwindCompiler`.

    * `:tailwind_config` - `t:tailwind_config/0` (optional).
    Defaults to `Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.js.eex")`.

    * `:live_socket_path` - `t:live_socket_path/0` (optional).
    Defaults to `"/live"`.

    * `:safe_code_check` - `t:safe_code_check/0` (optional).
    Defaults to `false`.

    * `:template_formats` - `t:template_formats/0` (optional).
    Defaults to:

          [
            {:heex, "HEEx (HTML)"},
            {:markdown, "Markdown (GitHub Flavored version)"}
          ]

    Note that the default config is merged with your config.

    * `lifecycle` - `t:lifecycle/0` (optional).
    Note that the default config is merged with your config.

    * `:extra_page_fields` - `t:extra_page_fields/0` (optional)

  ## Example

      iex> Beacon.Config.new(
        site: :my_site,
        data_source: MyApp.SiteDataSource,
        authorization_source: MyApp.SiteAuthnPolicy,
        tailwind_config: Path.join(Application.app_dir(:my_app, "priv"), "tailwind.config.js.eex"),
        template_formats: [
          {:custom_format, "My Custom Format"}
        ],
        lifecycle: [
          load_template: [
            {:custom_format,
             [
               validate: fn template, _metadata -> MyEngine.validate(template) end
             ]}
          ],
          render_template: [
            {:custom_format,
             [
               assigns: fn template, %{assigns: assigns} -> MyEngine.parse_to_html(template, assigns) end,
               compile: &Beacon.Template.HEEx.compile/2,
               eval: &Beacon.Template.HEEx.eval_ast/2
             ]}
          ],
          publish_page: [
            notify_admin: fn page -> {:cont, MyApp.send_email(page)} end
          ]
        ]
      )
      %Beacon.Config{
        site: :my_site,
        data_source: MyApp.SiteDataSource,
        authorization_source: MyApp.SiteAuthnPolicy,
        css_compiler: Beacon.TailwindCompiler,
        tailwind_config: "/my_app/priv/tailwind.config.js.eex",
        live_socket_path: "/live",
        safe_code_check: false,
        template_formats: [
          heex: "HEEx (HTML)",
          markdown: "Markdown (GitHub Flavored version)",
          custom_format: "My Custom Format"
        ],
        lifecycle: [
          load_template: [
            heex: [
              safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
              compile_heex: &Beacon.Template.HEEx.compile/2
            ],
            markdown: [
              convert_to_html: &Beacon.Template.Markdown.convert_to_html/2,
              safe_code_check: &Beacon.Template.HEEx.safe_code_check/2,
              compile_heex: &Beacon.Template.HEEx.compile/2
            ],
            custom_format: [
              validate: #Function<41.3316493/2 in :erl_eval.expr/6>
            ]
          ],
          render_template: [
            heex: [
              eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
            ],
            markdown: [
              eval_heex_ast: &Beacon.Template.HEEx.eval_ast/2
            ],
            custom_format: [
              assigns: #Function<41.3316493/2 in :erl_eval.expr/6>,
              compile: &Beacon.Template.HEEx.compile/2,
              eval: &Beacon.Template.HEEx.eval_ast/2
            ]
          ],
          create_page: [],
          update_page: [],
          publish_page: [
            notify_admin: #Function<42.3316493/1 in :erl_eval.expr/6>
          ]
        ],
        extra_page_fields: []
      }

  """
  @spec new([option]) :: t()
  def new(opts) do
    # TODO: validate opts

    template_formats =
      Keyword.merge(
        [
          {:heex, "HEEx (HTML)"},
          {:markdown, "Markdown (GitHub Flavored version)"}
        ],
        Keyword.get(opts, :template_formats, [])
      )

    lifecycle = [
      load_template: Keyword.merge(@default_load_template, get_in(opts, [:lifecycle, :load_template]) || []),
      render_template: Keyword.merge(@default_render_template, get_in(opts, [:lifecycle, :render_template]) || []),
      create_page: get_in(opts, [:lifecycle, :create_page]) || [],
      update_page: get_in(opts, [:lifecycle, :update_page]) || [],
      publish_page: get_in(opts, [:lifecycle, :publish_page]) || []
    ]

    opts =
      opts
      |> Keyword.put(:template_formats, template_formats)
      |> Keyword.put(:lifecycle, lifecycle)

    struct!(__MODULE__, opts)
  end

  @spec fetch!(Beacon.Types.Site.t()) :: t()
  def fetch!(site) do
    Registry.config!(site)
  end
end
