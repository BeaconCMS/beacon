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

  alias Beacon.Web.BeaconAssigns

  @typedoc """
  The AST representation of a `t:Phoenix.LiveView.Rendered.t/0` struct.
  """
  @type ast :: Macro.t()

  @type t :: Phoenix.LiveView.Rendered.t() | ast()

  @doc false
  def render_path(site, path_info, query_params \\ %{}) when is_atom(site) and is_list(path_info) and is_map(query_params) do
    case Beacon.RouterServer.lookup_page(site, path_info) do
      nil ->
        :error

      page ->
        page_module = Beacon.Loader.fetch_page_module(page.site, page.id)
        live_data = Beacon.Web.DataSource.live_data(site, path_info)
        beacon_assigns = BeaconAssigns.new(site, page, live_data, path_info, query_params)
        assigns = Map.put(live_data, :beacon, beacon_assigns)
        env = Beacon.Web.PageLive.make_env(site)

        template =
          site
          |> Beacon.apply_mfa(page_module, :page, [])
          |> Beacon.Lifecycle.Template.render_template(assigns, env)

        {:ok, template}
    end
  end

  @doc false
  def choose_template([primary]), do: primary
  def choose_template([primary | variants]), do: choose_template(variants, Enum.random(1..100), primary)

  @doc false
  def choose_template([], _, primary), do: primary
  def choose_template([{weight, template} | _], n, _) when weight >= n, do: template
  def choose_template([{weight, _} | variants], n, primary), do: choose_template(variants, n - weight, primary)
end
