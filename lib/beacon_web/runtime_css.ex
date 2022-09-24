defmodule BeaconWeb.RuntimeCSS do
  @moduledoc """
  Runtime recompilation/minification of CSS files.
  """

  use GenServer

  import Ecto.Query

  alias Beacon.Layouts.Layout
  alias Beacon.Pages.Page
  alias Beacon.Repo

  require Logger

  @subscriptions ~w(layouts pages)

  @subscribed_actions [
    :layout_created,
    :layout_updated,
    :layout_deleted,
    :page_created,
    :page_updated,
    :page_deleted
  ]

  @doc """
  Start the RuntimeCSS server and subscribe to page and layout actions.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {should_start, opts} = Keyword.pop(opts, :start?)

    if should_start do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      :ignore
    end
  end

  @doc """
  Recompiles CSS.
  """
  @spec recompile!(keyword()) :: 0 | no_return()
  def recompile!(opts \\ []) do
    tmp_dir = System.tmp_dir!()
    config_file = Path.join(tmp_dir, "tailwind.config.js")

    config =
      opts[:config_template]
      |> config_template()
      |> build_config(layout_bodies() ++ page_templates())

    File.write!(config_file, config)

    0 = Tailwind.run(:runtime, ~w(
      --config #{config_file}
      --input=css/app.css
      --output=../priv/static/assets/runtime.css
      --minify
    ))
  end

  @doc """
  Build CSS runtime config from an EEx template string.
  """
  @spec build_config(String.t(), [String.t()]) :: String.t()
  def build_config(config_template, page_templates) do
    EEx.eval_string(config_template, assigns: %{raw: IO.iodata_to_binary(page_templates)})
  end

  ## GenServer callbacks

  @impl GenServer
  def init(opts) do
    Enum.each(@subscriptions, &Phoenix.PubSub.subscribe(Beacon.PubSub, &1))
    {:ok, opts, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, opts) do
    # Just make sure Beacon.Repo is started.
    if Process.whereis(Repo) |> is_pid() do
      recompile!(opts)
      {:noreply, opts}
    else
      Process.sleep(500)
      {:ok, opts, {:continue, :init}}
    end
  end

  @impl GenServer
  def handle_info({action, _resource}, opts) when action in @subscribed_actions do
    Logger.debug("[RuntimeCSS] recompiling CSS because of #{action}")
    recompile!(opts)
    {:noreply, opts}
  end

  def handle_info(msg, opts) do
    Logger.debug("[RuntimeCSS] unhandled message #{inspect(msg)}")
    {:noreply, opts}
  end

  ## Helpers

  # Get all the layout bodies.
  defp layout_bodies do
    Repo.all(from l in Layout, select: l.body)
  end

  # Get all the page templates.
  defp page_templates do
    Repo.all(from p in Page, select: p.template)
  end

  # If we have no template passed in, then it must be from config.
  defp config_template(nil) do
    Application.fetch_env!(:beacon, __MODULE__) |> Keyword.fetch!(:config_template)
  end

  defp config_template(content), do: content
end
