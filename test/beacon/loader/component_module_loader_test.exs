defmodule Beacon.Loader.ComponentModuleLoaderTest do
  use Beacon.DataCase, async: false

  import Beacon.Fixtures
  alias Beacon.Content
  alias Beacon.Loader.ComponentModuleLoader

  @site :my_site

  defp render(rendered) do
    rendered
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(@site)})
    :ok
  end

  @tag :skip
  test "load empty module without components" do
    {:ok, mod} = ComponentModuleLoader.load_components(@site, [])
    assert mod.__info__(:functions) == [{:__components__, 0}]
  end

  @tag :skip
  test "inject beacon site into assigns" do
    component_fixture(name: "hello", body: "<%= @beacon_site %>")
    components = Content.list_components(@site, per_page: :infinity)

    {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
    assert render(mod.hello(%{})) == "my_site"
  end

  test "load component without attrs" do
    component_fixture(name: "hello", body: "<h1>Hello</h1>")
    components = Content.list_components(@site, per_page: :infinity)

    {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
    assert render(mod.hello(%{})) == "<h1>Hello</h1>"
  end

  # TODO: store and retrive attrs in %Beacon.Content.Component{}
  test "load component with attrs" do
    component_fixture(
      name: "say_hello",
      body: "<h1>Hello <%= @first_name %> <%= @last_name %></h1>",
      attrs: [%{name: "first_name", type: "string"}, %{name: "last_name", type: "string"}]
    )

    components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

    {:ok, mod} = ComponentModuleLoader.load_components(@site, components)

    assert render(mod.say_hello(%{first_name: "José", last_name: "Valim"})) == "<h1>Hello José Valim</h1>"
  end
end
