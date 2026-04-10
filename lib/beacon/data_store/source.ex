defmodule Beacon.DataStore.Source do
  @moduledoc """
  Defines a data source registered in a Beacon site.

  Data sources are declared in the site config and provide structured,
  cacheable data fetching with automatic invalidation and LiveView re-rendering.

  ## Fields

    * `:name` - Atom identifying this source (e.g., `:featured_posts`).
    * `:fetch` - Either an MFA tuple `{Module, :function, [:param_keys]}` or
      a function `fn params -> result end`. For MFA, the third element lists
      which keys from the params map are passed as arguments, in order.
    * `:params` - Declares which parameter keys this source expects.
    * `:ttl` - Time-to-live in milliseconds. Required. Acts as both a cache
      expiry and an active refresh trigger.
    * `:cache_key` - Strategy for deriving the cache key. `:params_hash`
      (default) uses `:erlang.phash2/1`. A `fn params -> term end` can be
      provided for custom keys.
    * `:invalidate_on` - List of PubSub topic suffixes that trigger
      automatic cache invalidation when the host app broadcasts on them.

  """

  @type t :: %__MODULE__{
          name: atom(),
          fetch: {module(), atom(), [atom()]} | (map() -> term()),
          params: [atom()],
          ttl: pos_integer(),
          cache_key: :params_hash | (map() -> term()),
          invalidate_on: [String.t()]
        }

  @enforce_keys [:name, :fetch, :ttl]
  defstruct [
    :name,
    :fetch,
    :ttl,
    params: [],
    cache_key: :params_hash,
    invalidate_on: []
  ]

  @doc """
  Builds and validates a Source struct from keyword options.

  Raises `ArgumentError` if required fields are missing.
  """
  @spec new!(keyword()) :: t()
  def new!(opts) when is_list(opts) do
    unless Keyword.has_key?(opts, :name), do: raise(ArgumentError, "data source requires :name")
    unless Keyword.has_key?(opts, :fetch), do: raise(ArgumentError, "data source requires :fetch")
    unless Keyword.has_key?(opts, :ttl), do: raise(ArgumentError, "data source requires :ttl")

    struct!(__MODULE__, opts)
  end
end
