defmodule Beacon.CSS.Storage do
  @moduledoc """
  Three-tier CSS storage: ETS (hot) -> S3 (warm) -> Recompile (cold).

  - **Hot tier** (ETS): In-memory, sub-microsecond reads. Populated on
    compile and restored from S3 on cache miss.
  - **Warm tier** (S3): Durable object storage. CSS bundle is stored as
    an Erlang term containing brotli, gzip, raw CSS, and candidates.
  - **Cold tier** (Recompile): Falls back to `Beacon.RuntimeCSS.load!/1`
    to recompile from scratch when no S3 copy exists.
  """

  require Logger
  import Ecto.Query

  @doc """
  Fetch compiled CSS for a site. Checks ETS first, then S3, then recompiles.

  Returns `{hash, brotli, gzip}`.
  """
  @spec fetch(atom()) :: {String.t(), binary() | nil, binary()}
  def fetch(site) do
    case fetch_from_ets(site) do
      {:ok, result} -> result
      :miss -> fetch_from_s3(site)
    end
  end

  @doc """
  Store compiled CSS in ETS (immediate) and S3 (async, durable).
  Also updates the DB manifest.

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

    # Warm tier (async)
    store_to_s3_async(site, hash, css, brotli, gzip, candidates)

    {hash, brotli, gzip}
  end

  defp fetch_from_ets(site) do
    case :ets.lookup(:beacon_assets, {site, :css}) do
      [{_, result}] -> {:ok, result}
      [] -> :miss
    end
  end

  defp fetch_from_s3(site) do
    case get_manifest(site) do
      %{s3_key: s3_key, hash: hash} ->
        case download_from_s3(s3_key) do
          {:ok, blob} ->
            %{brotli: brotli, gzip: gzip, candidates: candidates} = :erlang.binary_to_term(blob)

            # Restore hot tier
            :ets.insert(:beacon_assets, {{site, :css}, {hash, brotli, gzip}})

            # Restore known candidates
            :ets.insert(:beacon_runtime_poc, {{site, :css_candidates}, MapSet.new(candidates)})

            Logger.info("[Beacon.CSS] Restored CSS for #{site} from S3 (hash: #{String.slice(hash, 0..7)})")
            {hash, brotli, gzip}

          {:error, reason} ->
            Logger.warning("[Beacon.CSS] S3 fetch failed for #{site}: #{inspect(reason)}, recompiling")
            recompile(site)
        end

      nil ->
        Logger.info("[Beacon.CSS] No CSS manifest for #{site}, recompiling from scratch")
        recompile(site)
    end
  end

  defp recompile(site) do
    Beacon.RuntimeCSS.load!(site)

    case fetch_from_ets(site) do
      {:ok, result} -> result
      :miss -> raise Beacon.LoaderError, "CSS recompilation failed for site #{inspect(site)}"
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
      bucket = css_bucket()

      case ExAws.S3.put_object(bucket, s3_key, blob) |> ExAws.request() do
        {:ok, _} ->
          upsert_manifest(site, hash, s3_key)
          Logger.info("[Beacon.CSS] Stored CSS for #{site} in S3 (hash: #{String.slice(hash, 0..7)})")

        {:error, reason} ->
          Logger.warning("[Beacon.CSS] Failed to store CSS in S3 for #{site}: #{inspect(reason)}")
      end
    end)
  end

  defp get_manifest(site) do
    config = Beacon.Config.fetch!(site)
    config.repo.one(from(m in Beacon.CSS.Manifest, where: m.site == ^to_string(site)))
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

  defp download_from_s3(s3_key) do
    case ExAws.S3.get_object(css_bucket(), s3_key) |> ExAws.request() do
      {:ok, %{body: body}} -> {:ok, body}
      error -> {:error, error}
    end
  end

  defp css_bucket do
    Application.get_env(:beacon, :css_bucket) ||
      Application.get_env(:ex_aws, :s3, [])[:bucket] ||
      "beacon-assets"
  end
end
