defmodule Beacon.Private do
  @moduledoc false

  # Concentrate calls to private APIs so it's easier to track breaking changes and document them,
  # in case we need to make changes or understand why we had to call such APIs.

  # Should be avoided as much as possible.

  @doc """
  Fetch the host app `:otp_app` from the Repo config.
  """
  def otp_app!(%Beacon.Config{repo: repo}) do
    repo.config()[:otp_app] || raise Beacon.RuntimeError, "failed to discover :otp_app"
  rescue
    _ -> reraise Beacon.RuntimeError, [message: "failed to discover :otp_app, make sure Repo is started before Beacon"], __STACKTRACE__
  end

  @doc """
  On page navigation, the request might actually hit a different site than the one defined by the current session.

  That's the case for a live patch to a full URL, for eg:

  User is in https://sitea.com/page1 and clicks on a link to https://siteb.com/page2 through a `<.link patch={...}>` component,
  and since LV allows such navigation, we must do it as well but we need fetch the session defined for the requested URL and update the state accordingly,
  otherwise the page will either not be found or worse could render the wrong content.

  Relative paths are not supported because there's no safe way to know if a `/relative` path belongs to site A or B, that's a LV constraint.

  We use the private function `Phoenix.LiveView.Route.live_link_info/3` in order to keep the same behavior as LV.
  """
  def site_from_session(endpoint, router, url, view) do
    case live_link_info(endpoint, router, url) do
      {_,
       %{
         view: ^view,
         live_session: %{
           extra: %{
             # we don't execute the MFA here to avoid unnecessary computation and side-effects,
             # since we only need the static value of `site`
             session: {Beacon.Router, :session, [site, _]}
           }
         }
       }} ->
        site

      _ ->
        nil
    end
  end

  defp live_link_info(endpoint, router, url) do
    Phoenix.LiveView.Route.live_link_info_without_checks(endpoint, router, url)
  end

  def endpoint_config(otp_app, endpoint) do
    Phoenix.Endpoint.Supervisor.config(otp_app, endpoint)
  end

  def endpoint_host(otp_app, endpoint) do
    url_config = endpoint_config(otp_app, endpoint)[:url]
    host_to_binary(url_config[:host] || "localhost")
  end

  # https://github.com/phoenixframework/phoenix/blob/4ebefb9d1f710c576f08c517f5852498dd9b935c/lib/phoenix/endpoint/supervisor.ex#L301-L302
  defp host_to_binary({:system, env_var}), do: host_to_binary(System.get_env(env_var))
  defp host_to_binary(host), do: host

  def router(%{private: %{phoenix_router: router}}), do: router

  @doc """
  Returns the resolved assigns from mount hooks for a given `path_info`.
  """
  @spec route_assigns(Beacon.Types.Site.t(), [String.t()]) :: map()
  def route_assigns(site, path_info) when is_atom(site) and is_list(path_info) do
    config = Beacon.Config.fetch!(site)
    otp_app = otp_app!(config)
    host = endpoint_host(otp_app, config.endpoint)
    router = config.router

    with {
           %{
             phoenix_live_view:
               {Beacon.Web.PageLive, _, _,
                %{
                  extra: %{session: {Beacon.Router, :session, [^site, _]}, on_mount: on_mount}
                }}
           },
           _,
           _,
           _
         } <-
           router.__match_route__(router, "GET", host),
         socket = %Phoenix.LiveView.Socket{private: %{lifecycle: %Phoenix.LiveView.Lifecycle{mount: on_mount}}},
         {_, %Phoenix.LiveView.Socket{assigns: assigns}} <- Phoenix.LiveView.Lifecycle.mount(%{}, %{}, socket) do
      Map.drop(assigns, [:__changed__])
    else
      _ -> %{}
    end
  end

  def route_assigns(site, path_info) when is_atom(site) and is_binary(path_info) do
    path_info = for segment <- String.split(path_info, "/"), segment != "", do: segment
    route_assigns(site, path_info)
  end

  def route_assigns(_site, _path_info), do: %{}

  # https://github.com/phoenixframework/phoenix_live_view/blob/698950990440551cef8ab2b85fae32a86a4e7779/lib/phoenix_live_view/plug.ex#L21
  def live_session(session, conn) do
    case session do
      {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
        apply(mod, fun, [conn | args])

      %{} = session ->
        session

      nil ->
        %{}
    end
  end
end
