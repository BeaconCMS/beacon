defmodule Beacon.Web.API.Router do
  @moduledoc """
  API router for Beacon server endpoints.

  Mount in your Phoenix router:

      scope "/api", Beacon.Web.API do
        pipe_through [:api, Beacon.Web.API.AuthPlug]

        # Cache invalidation
        delete "/cache/:site/:endpoint_name", CacheController, :invalidate
        delete "/cache/:site/:endpoint_name/:result_alias", CacheController, :invalidate_query

        # Template push
        post "/templates/:site/push", TemplateController, :push

        # AST endpoints (for client SDKs)
        get "/ast/:site", ASTController, :index
        get "/ast/:site/*path", ASTController, :show
      end
  """
end
