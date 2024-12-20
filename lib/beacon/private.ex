defmodule Beacon.Private do
  @moduledoc false

  # Concentrate calls to private APIs so it's easier to track breaking changes and document them,
  # in case we need to make changes or understand why we had to call such APIs.

  # Should be avoided as much as possible.

  @phoenix_live_view_version to_string(Application.spec(:phoenix_live_view)[:vsn])

  @doc """
  On page navigation, the request might actually hit a different site than the one defined by the current session.

  That's the case for a live patch to a full URL, for eg:

  User is in https://sitea.com/page1 and clicks on a link to https://siteb.com/page2 through a `<.link patch={...}>` component,
  and since LV allows such navigation, we must do it as well but we need fetch the session defined for the requested URL and update the state accordingly,
  otherwise the page will either not be found or worse could render the wrong content.

  Relative paths are not supported because there's no safe way to know if a `/relative` path belongs to site A or B, that's a LV contraint.

  We use the private function `Phoenix.LiveView.Route.live_link_info/3` in order to keep the same behavior as LV.
  """
  def site_from_session(endpoint, router, url, view) do
    case live_link_info(endpoint, router, url) do
      {_,
       %{
         view: ^view,
         live_session: %{
           extra: %{
             session: %{"beacon_site" => site}
           }
         }
       }} ->
        site

      _ ->
        nil
    end
  end

  if Version.compare(@phoenix_live_view_version, "1.0.0") == :gt do
    defp live_link_info(endpoint, router, url) do
      Phoenix.LiveView.Route.live_link_info_without_checks(endpoint, router, url)
    end
  else
    defp live_link_info(endpoint, router, url) do
      Phoenix.LiveView.Route.live_link_info(endpoint, router, url)
    end
  end
end
