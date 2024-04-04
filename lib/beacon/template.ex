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

  defstruct [:site, :path, :page_module, :assigns, :env]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          path: String.t(),
          page_module: module(),
          assigns: Phoenix.LiveView.Socket.assigns(),
          env: Macro.Env.t()
        }
end

defmodule Beacon.Template do
  @moduledoc """
  Template for layouts, pages, and any other resource that display HTML/HEEx.

  Templates are defined as [Phoenix.LiveView.Rendered](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Rendered.html) structs,
  which holds nested static literal strings and also dynamic content for the LiveView engine.

  Template engines that do not support dynamic content can make use of the `:static` field to store its contents.
  """

  @typedoc """
  The AST representation of a `t:Phoenix.LiveView.Rendered.t/0` struct.
  """
  @type ast :: Macro.t()

  @type t :: Phoenix.LiveView.Rendered.t() | ast()

  @doc false
  # this function is used only for debugging HEEx templates
  # it is NOT supposed to be used to render templates
  def __render__(site, path_list) when is_list(path_list) do
    raise_not_found = fn -> raise BeaconWeb.NotFoundError, "could not find page #{inspect(path_list)} for site #{site}" end

    case Beacon.RouterServer.lookup_path(site, path_list) do
      {_path, page_id} ->
        page =
          case Beacon.Content.get_published_page(site, page_id) do
            nil -> raise_not_found.()
            page -> page
          end

        components_module = Beacon.Loader.fetch_components_module(site)
        page_module = Beacon.Loader.fetch_page_module(site, page_id)
        assigns = %{__changed__: %{}, __live_path__: [], __beacon_page_module__: page_module, __beacon_component_module__: components_module}
        Beacon.Lifecycle.Template.render_template(page, assigns, BeaconWeb.PageLive.make_env())

      _ ->
        raise_not_found.()
    end
  end

  @doc false
  def render(page_module, assigns \\ %{}) when is_atom(page_module) and is_map(assigns) do
    %{__changed__: %{}, __live_path__: [], beacon_path_params: %{}, beacon_live_data: %{}}
    |> Map.merge(assigns)
    |> page_module.render()
  end

  @doc false
  def choose_template([primary]), do: primary
  def choose_template([primary | variants]), do: choose_template(variants, Enum.random(1..100), primary)

  @doc false
  def choose_template([], _, primary), do: primary
  def choose_template([{weight, template} | _], n, _) when weight >= n, do: template
  def choose_template([{weight, _} | variants], n, primary), do: choose_template(variants, n - weight, primary)
end
