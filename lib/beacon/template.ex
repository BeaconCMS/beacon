defmodule Beacon.Template.LoadMetadata do
  @moduledoc """
  Metadata passed to page loading lifecycle.
  """

  defstruct [:site, :path]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path: String.t()
        }
end

defmodule Beacon.Template.RenderMetadata do
  @moduledoc """
  Metadata passed to page rendering lifecycle.
  """

  defstruct [:site, :path, :assigns, :env]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path: String.t(),
          assigns: Phoenix.LiveView.Socket.assigns(),
          env: Macro.Env.t()
        }
end

defmodule Beacon.Template do
  @typedoc """
  Compiled template.
  """
  @type ast :: Macro.t()

  @type t :: String.t() | ast()

  defguard is_ast(template) when not is_binary(template)

  @doc false
  # this function is used only for debugging HEEx templates
  # it is NOT supposed to be used to render templates
  def __render__(site, path_list) when is_list(path_list) do
    case Beacon.Router.lookup_path(site, path_list) do
      {{site, path}, {_page_id, _layout_id, format, template, _page_module, _component_module}} ->
        Beacon.Lifecycle.Template.render_template(site, template, format,
          path: path,
          assigns: %{__changed__: %{}, __live_path__: [], __beacon_page_module__: nil, __beacon_component_module__: nil},
          env: BeaconWeb.PageLive.make_env()
        )

      _ ->
        raise BeaconWeb.NotFoundError, "page not found: #{inspect(path_list)}"
    end
  end
end
