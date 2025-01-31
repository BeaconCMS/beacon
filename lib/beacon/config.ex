defmodule Beacon.Config do
  @moduledoc """
  Configuration for sites.

  Each site is started with this configuration and its values are stored in a registry that can be fetched at runtime
  or updated with `update_value/3`.

  See `new/1` for available options and examples.

  """

  @doc false
  use GenServer

  alias Beacon.Content
  alias Beacon.ConfigError

  @doc false
  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  @doc false
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: Beacon.Registry.via({config.site, __MODULE__}, config))
  end

  @doc false
  def init(config) do
    :pg.join(:beacon_cluster, config.site, self())
    {:ok, config}
  end

  @typedoc """
  Host application Endpoint module.
  """
  @type endpoint :: module()

  @typedoc """
  Host application Router module.
  """
  @type router :: module()

  @typedoc """
  Host application Repo module.
  """
  @type repo :: module()

  @typedoc """
  Defines the mode which the site will operate.

  Default is `:live` which will load resources during boot, broadcast events on content change,
  and execute operations asyncly. That's the normal mode for production.

  The `:testing` mode is suited for testing environments,
  you should always use it when running tests that involve Beacon resources.

  And the `:manual` mode is similar to `:testing` but it won't boot load any resource,
  it's useful to seed data.

  You can always change to `:live` mode at runtime by calling `Beacon.boot/1`.
  """
  @type mode :: :live | :testing | :manual

  @typedoc """
  A module that implements `Beacon.RuntimeCSS`.
  """
  @type css_compiler :: module()

  @typedoc """
  Path to a custom Tailwind config.

  ## Example

      # use the config file `priv/tailwind.config.js` from your app named `my_app`
      Path.join(Application.app_dir(:my_app, "priv"), "tailwind.config.js")

  See `Beacon.RuntimeCSS.TailwindCompiler` for more info.
  """
  @type tailwind_config :: Path.t()

  @typedoc """
  Path to a custom Tailwind CSS

  Note that Tailwind base, components, and utilities must be imported in this file.

  ## Example

      # use the file `assets/css/app.css` from your app named `my_app`
      Path.join([Application.app_dir(:my_app, "assets"), "css", "app.css"])

  See `Beacon.RuntimeCSS.TailwindCompiler` for more info.
  """
  @type tailwind_css :: Path.t()

  @typedoc """
  Path of a LiveView socket where Beacon should connect to.
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
  Register specific media types allowed for upload. Catchalls are not allowed.
  """
  @type allowed_media_accept_types :: [media_type :: String.t()]

  @typedoc """
  Register providers and validations for media types. Catchalls are allowed.
  """
  @type media_type_configs :: [{media_type :: String.t(), media_type_config()}]

  @typedoc """
  Individual media type configs
  """
  @type media_type_config :: [
          {:processor, processor_fun :: (Beacon.MediaLibrary.UploadMetadata.t() -> Beacon.MediaLibrary.UploadMetadata.t())},
          {:validations,
           list(
             validation_fun ::
               (Ecto.Changeset.t(), Beacon.MediaLibrary.UploadMetadata.t() -> Ecto.Changeset.t())
               | {validation_fun :: (Ecto.Changeset.t(), Beacon.MediaLibrary.UploadMetadata.t() -> Ecto.Changeset.t()), validation_config :: term()}
           )},
          {:providers, list(provider :: module() | {provider :: module(), provider_config :: term()})}
        ]

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
                   (template :: String.t(), Beacon.Template.LoadMetadata.t() ->
                      {:cont, String.t()} | {:halt, String.t()} | {:halt, Exception.t()})}
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
          | {:after_create_page, [{identifier :: atom(), fun :: (Content.Page.t() -> {:cont, Content.Page.t()} | {:halt, Exception.t()})}]}
          | {:after_update_page, [{identifier :: atom(), fun :: (Content.Page.t() -> {:cont, Content.Page.t()} | {:halt, Exception.t()})}]}
          | {:after_publish_page, [{identifier :: atom(), fun :: (Content.Page.t() -> {:cont, Content.Page.t()} | {:halt, Exception.t()})}]}
          | {:upload_asset,
             [
               {identifier :: atom(), fun :: (Ecto.Schema.t(), Beacon.MediaLibrary.UploadMetadata.t() -> {:cont, any()} | {:halt, Exception.t()})}
             ]}

  @typedoc """
  Add extra fields to pages.
  """
  @type extra_page_fields :: [module()]

  @typedoc """
  Add extra fields to pages.
  """
  @type extra_asset_fields :: [extra_asset_field()]

  @typedoc """
  Add extra fields to pages.
  """
  @type extra_asset_field :: {media_type :: String.t(), [module()]}

  @typedoc """
  Default meta tags added to new pages.
  """
  @type default_meta_tags :: [%{binary() => binary()}]

  @typedoc """
  The strategy for pre-loading page modules at boot time.
  """
  @type page_warming :: {:shortest_paths, integer()} | {:specify_paths, [String.t()]} | :none

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          endpoint: endpoint(),
          router: router(),
          repo: repo(),
          mode: mode(),
          css_compiler: css_compiler(),
          tailwind_config: tailwind_config(),
          tailwind_css: tailwind_css(),
          live_socket_path: live_socket_path(),
          safe_code_check: safe_code_check(),
          template_formats: template_formats(),
          assets: media_type_configs(),
          allowed_media_accept_types: allowed_media_accept_types(),
          lifecycle: lifecycle(),
          extra_page_fields: extra_page_fields(),
          extra_asset_fields: extra_asset_fields(),
          default_meta_tags: default_meta_tags(),
          page_warming: page_warming()
        }

  @default_load_template [
    {:heex, []},
    {:markdown,
     [
       convert_to_html: &Beacon.Template.Markdown.convert_to_html/2
     ]}
  ]

  @default_render_template [
    {:heex, []},
    {:markdown, []}
  ]

  @default_media_types ["image/jpeg", "image/gif", "image/png", "image/webp", ".pdf"]

  defstruct site: nil,
            endpoint: nil,
            router: nil,
            repo: nil,
            mode: :live,
            # TODO: rename to `authorization_policy`, see https://github.com/BeaconCMS/beacon/pull/563
            # authorization_source: Beacon.Authorization.DefaultPolicy,
            css_compiler: Beacon.RuntimeCSS.TailwindCompiler,
            tailwind_config: nil,
            tailwind_css: nil,
            live_socket_path: "/live",
            # TODO: change safe_code_check to true when it's ready to parse complex codes
            safe_code_check: false,
            template_formats: [
              {:heex, "HEEx (HTML)"},
              {:markdown, "Markdown (GitHub Flavored version)"}
            ],
            assets: [],
            allowed_media_accept_types: @default_media_types,
            lifecycle: [
              load_template: @default_load_template,
              render_template: @default_render_template,
              after_create_page: [],
              after_update_page: [],
              after_publish_page: []
            ],
            extra_page_fields: [],
            extra_asset_fields: [],
            default_meta_tags: [],
            page_warming: {:shortest_paths, 10}

  @type option ::
          {:site, Beacon.Types.Site.t()}
          | {:endpoint, endpoint()}
          | {:router, router()}
          | {:repo, repo()}
          | {:mode, mode()}
          | {:css_compiler, css_compiler()}
          | {:tailwind_config, tailwind_config()}
          | {:tailwind_css, tailwind_css()}
          | {:live_socket_path, live_socket_path()}
          | {:safe_code_check, safe_code_check()}
          | {:template_formats, template_formats()}
          | {:assets, media_type_configs()}
          | {:allowed_media_accept_types, allowed_media_accept_types()}
          | {:lifecycle, lifecycle()}
          | {:extra_page_fields, extra_page_fields()}
          | {:extra_asset_fields, extra_asset_fields()}
          | {:default_meta_tags, default_meta_tags()}
          | {:page_warming, page_warming()}

  @doc """
  Build a new `%Beacon.Config{}` instance to hold the entire configuration for each site.

  ## Options

    * `:site` - `t:Beacon.Types.Site.t/0` (required)

    * `:endpoint` - `t:endpoint/0` (required)

    * `:router` - `t:router/0` (required)

    * `:repo` - `t:repo/0` (required)

    * `:mode` - `t:mode/0` (optional). Defaults to `:live`.

    * `css_compiler` - `t:css_compiler/0` (optional). Defaults to `Beacon.RuntimeCSS.TailwindCompiler`.

    * `:tailwind_config` - `t:tailwind_config/0` (optional). Defaults to `Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.bundle.js")`.

    * `:tailwind_css` - `t:tailwind_css/0` (optional). Defaults to `Path.join(Application.app_dir(:beacon, "priv"), "tailwind.css")`.

    * `:live_socket_path` - `t:live_socket_path/0` (optional). Defaults to `"/live"`.

    * `:safe_code_check` - `t:safe_code_check/0` (optional). Defaults to `false`.

    * `:template_formats` - `t:template_formats/0` (optional).

        Defaults to:

              [
                {:heex, "HEEx (HTML)"},
                {:markdown, "Markdown (GitHub Flavored version)"}
              ]

    Note that the default config is merged with your config.

    * `lifecycle` - `t:lifecycle/0` (optional).

    Note that the default config is merged with your config.

    * `:extra_page_fields` - `t:extra_page_fields/0` (optional). Defaults to `[]`.

    * `:extra_asset_fields` - `t:extra_asset_fields/0` (optional). Defaults to `[]`.

    * `:default_meta_tags` - `t:default_meta_tags/0` (optional). Defaults to `%{}`.

    * `:page_warming` - `t:page_warming/0` (optional). Defaults to `{:shortest_paths, 10}`.

  ## Example

      iex> Beacon.Config.new(
        site: :my_site,
        endpoint: MyAppWeb.Endpoint,
        router: MyAppWeb.Router,
        repo: MyApp.Repo,
        tailwind_config: Path.join(Application.app_dir(:my_app, "priv"), "tailwind.config.js"),
        tailwind_css: Path.join([Application.app_dir(:my_app, "assets"), "css", "app.css"]),
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
               assigns: fn %Phoenix.LiveView.Rendered{static: template} , %{assigns: assigns} -> MyEngine.parse_to_html(template, assigns) end
             ]}
          ],
          after_publish_page: [
            notify_admin: fn page -> {:cont, MyApp.Admin.send_email(page)} end
          ]
        ],
        page_warming: {:specify_paths, ["/", "/home", "/blog"]}
      )
      %Beacon.Config{
        site: :my_site,
        endpoint: MyAppWeb.Endpoint,
        router: MyAppWeb.Router,
        repo: MyApp.Repo,
        mode: :live,
        css_compiler: Beacon.RuntimeCSS.TailwindCompiler,
        tailwind_config: "/my_app/priv/tailwind.config.js",
        tailwind_css: "/my_app/assets/css/app.css",
        live_socket_path: "/live",
        safe_code_check: false,
        template_formats: [
          heex: "HEEx (HTML)",
          markdown: "Markdown (GitHub Flavored version)",
          custom_format: "My Custom Format"
        ],
        media_types: ["image/jpeg", "image/gif", "image/png", "image/webp"],
        assets:[
          {"image/*", [providers: [Beacon.MediaLibrary.Provider.Repo], validations: [&SomeModule.some_function/2]]},
        ],
        lifecycle: [
          load_template: [
            heex: [],
            markdown: [
              convert_to_html: &Beacon.Template.Markdown.convert_to_html/2,
            ],
            custom_format: [
              validate: #Function<41.3316493/2 in :erl_eval.expr/6>
            ]
          ],
          render_template: [
            heex: [],
            markdown: [],
            custom_format: [
              assigns: #Function<41.3316493/2 in :erl_eval.expr/6>
            ]
          ],
          after_create_page: [],
          after_update_page: [],
          after_publish_page: [
            notify_admin: #Function<42.3316493/1 in :erl_eval.expr/6>
          ],
          upload_asset: [],
        ],
        extra_page_fields: [],
        extra_asset_fields: [],
        default_meta_tags: [],
        page_warming: {:specify_paths, ["/", "/home", "/blog"]}
      }

  """
  @spec new([option]) :: t()
  def new(opts) do
    # TODO: validate opts, maybe use nimble_options

    opts[:site] || raise ConfigError, "missing required option :site"
    opts[:endpoint] || raise ConfigError, "missing required option :endpoint"
    opts[:router] || raise ConfigError, "missing required option :router"
    ensure_repo(opts[:repo])

    tailwind_css = Keyword.get(opts, :tailwind_css) || Path.join(Application.app_dir(:beacon, "priv"), "tailwind.css")

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
      after_create_page: get_in(opts, [:lifecycle, :after_create_page]) || [],
      after_update_page: get_in(opts, [:lifecycle, :after_update_page]) || [],
      after_publish_page: get_in(opts, [:lifecycle, :after_publish_page]) || [],
      upload_asset: get_in(opts, [:lifecycle, :upload_asset]) || [thumbnail: &Beacon.Lifecycle.Asset.thumbnail/2]
    ]

    allowed_media_accept_types = Keyword.get(opts, :allowed_media_accept_types, @default_media_types)
    validate_allowed_media_accept_types!(allowed_media_accept_types)

    assigned_assets = Keyword.get(opts, :assets, [])
    assets = process_assets_config(allowed_media_accept_types, assigned_assets)

    default_meta_tags = Keyword.get(opts, :default_meta_tags, [])
    extra_asset_fields = Keyword.get(opts, :extra_asset_fields, [{"image/*", [Beacon.MediaLibrary.AssetFields.AltText]}])

    page_warming = Keyword.get(opts, :page_warming, {:shortest_paths, 10})

    opts =
      opts
      |> Keyword.put(:tailwind_config, ensure_tailwind_config(opts[:tailwind_config]))
      |> Keyword.put(:tailwind_css, tailwind_css)
      |> Keyword.put(:template_formats, template_formats)
      |> Keyword.put(:lifecycle, lifecycle)
      |> Keyword.put(:allowed_media_accept_types, allowed_media_accept_types)
      |> Keyword.put(:assets, assets)
      |> Keyword.put(:default_meta_tags, default_meta_tags)
      |> Keyword.put(:extra_asset_fields, extra_asset_fields)
      |> Keyword.put(:page_warming, page_warming)

    struct!(__MODULE__, opts)
  end

  @doc """
  Returns the `Beacon.Config` for `site`.
  """
  @spec fetch!(Beacon.Types.Site.t()) :: t()
  def fetch!(site) when is_atom(site) do
    case Beacon.Registry.lookup({site, __MODULE__}) do
      {_pid, config} ->
        config

      _ ->
        raise ConfigError, """
        site #{inspect(site)} not found. Make sure it's configured and started,
        see `Beacon.start_link/1` for more info.
        """
    end
  end

  @doc """
  Updates `key` with `value` for the `site` configuration, at runtime.
  """
  @spec update_value(Beacon.Types.Site.t(), atom(), any()) :: t() | :error
  def update_value(site, key, value) do
    GenServer.call(name(site), {:update_value, key, value})
  end

  @doc """
  From a `Beacon.Config`, fetch the asset config for a given media type, raising when unsuccessful.

  ## Example

      iex> beacon_config = Beacon.Config.fetch!(:some_site)
      iex> jpeg_config = config_for_media_type(beacon_config, "image/jpeg")

  """
  @spec config_for_media_type(t(), String.t()) :: media_type_config()
  def config_for_media_type(%Beacon.Config{} = beacon_config, media_type) do
    case get_media_type_config(beacon_config.assets, media_type) do
      nil ->
        raise ConfigError, """
        Expected to find a `media_type()` configuration for `#{media_type}` in `Beacon.Config.assets`.

        You can key that configuration with `#{media_type}` or a catchall like `#{build_generic_media_type(media_type)}`
        """

      {_, config} ->
        config

      config ->
        raise ConfigError, """
        expected to find a `t:media_type/0` configuration for `#{media_type}` in `Beacon.Config.assets` to be of type `t:media_type_config/0`

          Got:

          #{inspect(config)}
        """
    end
  end

  def config_for_media_type(non_config, _) do
    raise ConfigError, """
    expected config to be of type `t:Beacon.Config.t/0`

      Got:

      #{inspect(non_config)}

    """
  end

  @doc """
  Searches a config option for the given media type.

  For config options based on media type, such as `:assets` and `:extra_asset_fields`,
  this function will check for the presence of `media_type`, returning the config for
  that specific type, or `nil` if the type is not present.

  ## Examples

      iex> beacon_config = Beacon.Config.fetch!(:some_site)
      iex> jpeg_config = config_for_media_type(beacon_config.assets, "image/jpeg")

      iex> beacon_config = Beacon.Config.fetch!(:some_site)
      iex> webp_config = config_for_media_type(beacon_config.extra_asset_fields, "image/webp")

      iex> beacon_config = Beacon.Config.fetch!(:some_site)
      iex> nil = config_for_media_type(beacon_config.assets, "invalid/foo")

  """
  @spec get_media_type_config(media_type_configs(), String.t()) :: media_type_config() | nil
  @spec get_media_type_config(extra_asset_fields(), String.t()) :: extra_asset_field() | nil
  def get_media_type_config(configs, media_type) do
    generic_type = build_generic_media_type(media_type)

    Enum.find(configs, fn {type, _} ->
      type == media_type || type == generic_type
    end)
  end

  defp build_generic_media_type(media_type) do
    [cat, _] = String.split(media_type, "/")
    "#{cat}/*"
  end

  defp validate_allowed_media_accept_types!(allowed_media_accept_types) do
    Enum.each(allowed_media_accept_types, fn media_type ->
      validate_media_accept_type(media_type)
    end)
  end

  defp validate_media_accept_type(media_type) do
    if String.contains?(media_type, "/") do
      do_validate_media_accept_type(media_type)
    else
      validate_accept_extension(media_type)
    end
  end

  defp do_validate_media_accept_type(media_type) do
    case Plug.Conn.Utils.media_type(media_type) do
      {:ok, category, "*", _} ->
        if Enum.member?(["image", "audio", "video"], category) do
          media_type
        else
          raise ConfigError, """
          Catchall Media Types are only allowed for `image`, `audio`, `video` media types.
          Media Type: #{media_type}
          """
        end

      :error ->
        raise_invalid_media_type(media_type)

      _ ->
        media_type
    end
  end

  # .some_ext (not checking for valid extension)
  defp validate_accept_extension(<<46, _rest::binary>> = media_type), do: media_type

  # catchall
  defp validate_accept_extension(media_type),
    do: raise(ConfigError, "`#{media_type}` does not appear to be a media type, extensions must begin with a `.`")

  defp process_assets_config(allowed_media_accept_types, assigned_assets) do
    Enum.reduce(
      allowed_media_accept_types,
      assigned_assets,
      fn media_type, acc ->
        if String.contains?(media_type, "/") do
          ensure_provider(acc, media_type)
        else
          ensure_provider_for_extension(acc, media_type)
        end
      end
    )
    |> Enum.map(fn
      {media_type, config} ->
        config =
          config
          |> Keyword.put_new(:validations, [])
          |> ensure_processor(media_type)

        {media_type, config}
    end)
  end

  defp ensure_provider(configs, media_type) do
    if :error == Plug.Conn.Utils.media_type(media_type) do
      raise_invalid_media_type(media_type)
    end

    if get_media_type_config(configs, media_type) do
      configs
    else
      configs ++ [{media_type, [{:providers, [Beacon.MediaLibrary.Provider.Repo]}]}]
    end
  end

  defp ensure_provider_for_extension(configs, <<46, extension::binary>>) do
    if MIME.has_type?(extension) do
      media_type = MIME.type(extension)
      ensure_provider(configs, media_type)
    else
      raise ConfigError, """
      No known media type for: #{extension}
      """
    end
  end

  defp ensure_provider_for_extension(_configs, extension_without_leading_dot),
    do: raise(ConfigError, "`#{extension_without_leading_dot}` does not appear to be a media type, extensions must begin with a `.`")

  defp raise_invalid_media_type(media_type) do
    raise ConfigError, "Unknown Media type: #{media_type}"
  end

  defp ensure_processor(config, media_type) do
    processor =
      case Plug.Conn.Utils.media_type(media_type) do
        {:ok, "image", _, _} -> &Beacon.MediaLibrary.Processors.Image.process!/1
        _ -> &Beacon.MediaLibrary.Processors.Default.process!/1
      end

    Keyword.put_new(config, :processor, processor)
  end

  # https://github.com/elixir-ecto/ecto/blob/88100b862f69682e4bec4bd11ab8d459346817b0/lib/mix/ecto.ex#L62
  defp ensure_repo(nil = _repo) do
    raise ConfigError, "missing required option :repo"
  end

  defp ensure_repo(repo) do
    case Code.ensure_compiled(repo) do
      {:module, _} ->
        if function_exported?(repo, :__adapter__, 0) do
          repo
        else
          raise ConfigError, """
          Module #{inspect(repo)} is not an Ecto.Repo.
          """
        end

      {:error, error} ->
        raise ConfigError, """
        Could not load #{inspect(repo)}, error: #{inspect(error)}
        """
    end
  end

  defp ensure_tailwind_config(nil = _config), do: Path.join(Application.app_dir(:beacon, "priv"), "tailwind.config.bundle.js")

  defp ensure_tailwind_config(config) when is_binary(config) do
    if Path.extname(config) == ".js" do
      config
    else
      invalid_tailwind_config!(config)
    end
  end

  defp ensure_tailwind_config(config), do: invalid_tailwind_config!(config)

  defp invalid_tailwind_config!(config) do
    raise ConfigError, """
    invalid tailwind config

    Expected an existing .js file, got:

      #{inspect(config)}

    """
  end

  @doc false
  def env_test? do
    Code.ensure_loaded?(Mix.Project) and Mix.env() == :test
  end

  # Server

  def handle_call(:current_node, _from, config) do
    {:reply, Node.self(), config}
  end

  @doc false
  def handle_call({:update_value, key, value}, _from, config) do
    %{site: site} = config

    result =
      case Registry.update_value(Beacon.Registry, {site, __MODULE__}, &%{&1 | key => value}) do
        {new, _old} -> new
        error -> error
      end

    {:reply, result, config}
  end
end
