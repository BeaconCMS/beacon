defmodule Beacon.DataSource.Behaviour do
  @moduledoc false

  @optional_callbacks page_title: 1, meta_tags: 1

  @callback live_data(path :: [String.t()], params :: map()) :: map()

  @type page_title_opts :: %{path: [String.t()], params: map(), beacon_live_data: map(), page_title: String.t()}
  @callback page_title(page_title_opts()) :: String.t()

  @type meta_tags_opts :: %{path: [String.t()], params: map(), beacon_live_data: map(), meta_tags: [map()]}
  @callback meta_tags(meta_tags_opts()) :: [map()]
end
