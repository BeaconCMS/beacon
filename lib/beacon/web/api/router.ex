defmodule Beacon.Web.API.Router do
  @moduledoc """
  API router for Beacon server endpoints.

  Mount in your Phoenix router:

      scope "/api", Beacon.Web.API do
        pipe_through [:api, Beacon.Web.API.AuthPlug]
        delete "/cache/:site/:endpoint_name", CacheController, :invalidate
        delete "/cache/:site/:endpoint_name/:result_alias", CacheController, :invalidate_query
        post "/templates/:site/push", TemplateController, :push
      end
  """
end
