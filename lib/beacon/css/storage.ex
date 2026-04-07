defmodule Beacon.CSS.Storage do
  @moduledoc """
  Three-tier CSS storage: ETS (hot) -> S3 (warm) -> Recompile (cold).

  If no S3 bucket is configured, the warm tier is skipped and CSS
  is treated as ephemeral — ETS only, recompiled on restart.

  - **Hot tier** (ETS): In-memory, sub-microsecond reads.
  - **Warm tier** (S3): Durable object storage, optional.
  - **Cold tier** (Recompile): Zig NIF recompile from candidates.
  """

  require Logger
  import Ecto.Query

  @doc """
  Fetch compiled CSS for a site. Checks ETS first, then S3 (if configured),
  then recompiles.

  Returns `{hash, brotli, gzip}`.
  """
  @spec fetch(atom()) :: {String.t(), binary() | nil, binary()}
  def fetch(site) do
    case fetch_from_ets(site) do
      {:ok, result} -> result
      :miss -> fetch_from_warm(site)
    end
  end

  @doc """
  Store compiled CSS in ETS (immediate) and S3 (async, if configured).

  Returns `{hash, brotli, gzip}`.
  """
  @spec store(atom(), binary(), MapSet.t()) :: {String.t(), binary() | nil, binary()}
  def store(site, css, candidates) do
    hash = :crypto.hash(:md5, css) |> Base.encode16(case: :lower)

    brotli =
      case ExBrotli.compress(css) do
        {:ok, compressed} -> compressed
        _ -> nil
      end

    gzip = :zlib.gzip(css)

    # Hot tier
    :ets.insert(:beacon_assets, {{site, :css}, {hash, brotli, gzip}})

    # Warm tier (async, only if S3 configured)
    if s3_available?() do
      store_to_s3_async(site, hash, css, brotli, gzip, candidates)
    end

    {hash, brotli, gzip}
  end

  # ---------------------------------------------------------------------------
  # Tier 1: ETS
  # ---------------------------------------------------------------------------

  defp fetch_from_ets(site) do
    case :ets.lookup(:beacon_assets, {site, :css}) do
      [{_, result}] -> {:ok, result}
      [] -> :miss
    end
  end

  # ---------------------------------------------------------------------------
  # Tier 2: S3 (skipped if not configured)
  # ---------------------------------------------------------------------------

  defp fetch_from_warm(site) do
    if s3_available?() do
      fetch_from_s3(site)
    else
      recompile(site)
    end
  end

  defp fetch_from_s3(site) do
    case get_manifest(site) do
      %{s3_key: s3_key, hash: hash} ->
        case download_from_s3(s3_key) do
          {:ok, blob} ->
            %{brotli: brotli, gzip: gzip, candidates: candidates} = :erlang.binary_to_term(blob)

            :ets.insert(:beacon_assets, {{site, :css}, {hash, brotli, gzip}})
            :ets.insert(:beacon_runtime_poc, {{site, :css_candidates}, MapSet.new(candidates)})

            Logger.info("[Beacon.CSS] Restored CSS for #{site} from S3 (hash: #{String.slice(hash, 0..7)})")
            {hash, brotli, gzip}

          {:error, reason} ->
            Logger.warning("[Beacon.CSS] S3 fetch failed for #{site}: #{inspect(reason)}, recompiling")
            recompile(site)
        end

      nil ->
        recompile(site)
    end
  end

  defp store_to_s3_async(site, hash, css, brotli, gzip, candidates) do
    Task.start(fn ->
      blob =
        :erlang.term_to_binary(%{
          hash: hash,
          brotli: brotli,
          gzip: gzip,
          raw_css: css,
          candidates: MapSet.to_list(candidates),
          compiled_at: DateTime.utc_now()
        })

      s3_key = "beacon/css/#{site}/#{hash}"

      case ExAws.S3.put_object(css_bucket(), s3_key, blob) |> ExAws.request() do
        {:ok, _} ->
          upsert_manifest(site, hash, s3_key)
          Logger.info("[Beacon.CSS] Stored CSS for #{site} in S3 (hash: #{String.slice(hash, 0..7)})")

        {:error, reason} ->
          Logger.warning("[Beacon.CSS] Failed to store CSS in S3 for #{site}: #{inspect(reason)}")
      end
    end)
  end

  defp download_from_s3(s3_key) do
    case ExAws.S3.get_object(css_bucket(), s3_key) |> ExAws.request() do
      {:ok, %{body: body}} -> {:ok, body}
      error -> {:error, error}
    end
  end

  # ---------------------------------------------------------------------------
  # Tier 3: Recompile
  # ---------------------------------------------------------------------------

  defp recompile(site) do
    Beacon.RuntimeCSS.load!(site)

    case fetch_from_ets(site) do
      {:ok, result} -> result
      :miss -> raise Beacon.LoaderError, "CSS recompilation failed for site #{inspect(site)}"
    end
  end

  # ---------------------------------------------------------------------------
  # DB manifest
  # ---------------------------------------------------------------------------

  defp get_manifest(site) do
    config = Beacon.Config.fetch!(site)
    config.repo.one(from(m in Beacon.CSS.Manifest, where: m.site == ^to_string(site)))
  rescue
    _ -> nil
  end

  defp upsert_manifest(site, hash, s3_key) do
    config = Beacon.Config.fetch!(site)

    config.repo.insert!(
      %Beacon.CSS.Manifest{
        site: to_string(site),
        hash: hash,
        s3_key: s3_key,
        inserted_at: DateTime.utc_now()
      },
      on_conflict: {:replace, [:hash, :s3_key, :inserted_at]},
      conflict_target: :site
    )
  end

  # ---------------------------------------------------------------------------
  # S3 availability
  # ---------------------------------------------------------------------------

  defp s3_available? do
    css_bucket() != nil
  end

  defp css_bucket do
    Application.get_env(:beacon, :css_bucket)
  end
end
