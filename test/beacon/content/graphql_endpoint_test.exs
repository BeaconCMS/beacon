defmodule Beacon.Content.GraphQLEndpointTest do
  use Beacon.DataCase, async: true

  alias Beacon.Content
  alias Beacon.Content.GraphQLEndpoint

  @site :my_site

  describe "graphql endpoint CRUD" do
    test "create_graphql_endpoint/1" do
      attrs = %{
        site: @site,
        name: "blog_api",
        url: "https://api.example.com/graphql",
        auth_type: "bearer",
        auth_value_encrypted: "test-token"
      }

      assert {:ok, %GraphQLEndpoint{} = endpoint} = Content.create_graphql_endpoint(attrs)
      assert endpoint.name == "blog_api"
      assert endpoint.url == "https://api.example.com/graphql"
      assert endpoint.auth_type == "bearer"
      assert endpoint.default_ttl == 60
    end

    test "create_graphql_endpoint/1 validates url format" do
      attrs = %{site: @site, name: "bad", url: "not-a-url"}

      assert {:error, changeset} = Content.create_graphql_endpoint(attrs)
      assert errors_on(changeset)[:url]
    end

    test "create_graphql_endpoint/1 validates name format" do
      attrs = %{site: @site, name: "Bad Name!", url: "https://api.example.com/graphql"}

      assert {:error, changeset} = Content.create_graphql_endpoint(attrs)
      assert errors_on(changeset)[:name]
    end

    test "create_graphql_endpoint/1 validates auth_type" do
      attrs = %{site: @site, name: "test", url: "https://api.example.com/graphql", auth_type: "invalid"}

      assert {:error, changeset} = Content.create_graphql_endpoint(attrs)
      assert errors_on(changeset)[:auth_type]
    end

    test "create_graphql_endpoint/1 enforces unique name per site" do
      attrs = %{site: @site, name: "unique_test", url: "https://api.example.com/graphql"}

      assert {:ok, _} = Content.create_graphql_endpoint(attrs)
      assert {:error, changeset} = Content.create_graphql_endpoint(attrs)
      # Unique constraint on [:site, :name] — error appears on :site (first column)
      assert errors_on(changeset)[:site]
    end

    test "list_graphql_endpoints/1" do
      attrs1 = %{site: @site, name: "api_a", url: "https://a.example.com/graphql"}
      attrs2 = %{site: @site, name: "api_b", url: "https://b.example.com/graphql"}

      {:ok, _} = Content.create_graphql_endpoint(attrs1)
      {:ok, _} = Content.create_graphql_endpoint(attrs2)

      endpoints = Content.list_graphql_endpoints(@site)
      assert length(endpoints) >= 2
      names = Enum.map(endpoints, & &1.name)
      assert "api_a" in names
      assert "api_b" in names
    end

    test "update_graphql_endpoint/2" do
      {:ok, endpoint} = Content.create_graphql_endpoint(%{
        site: @site, name: "updatable", url: "https://old.example.com/graphql"
      })

      assert {:ok, updated} = Content.update_graphql_endpoint(endpoint, %{url: "https://new.example.com/graphql"})
      assert updated.url == "https://new.example.com/graphql"
    end

    test "delete_graphql_endpoint/1" do
      {:ok, endpoint} = Content.create_graphql_endpoint(%{
        site: @site, name: "deletable", url: "https://del.example.com/graphql"
      })

      assert {:ok, _} = Content.delete_graphql_endpoint(endpoint)
      assert Content.get_graphql_endpoint(@site, endpoint.id) == nil
    end

    test "get_graphql_endpoint_by/2" do
      {:ok, _} = Content.create_graphql_endpoint(%{
        site: @site, name: "findme", url: "https://find.example.com/graphql"
      })

      assert %GraphQLEndpoint{name: "findme"} = Content.get_graphql_endpoint_by(@site, name: "findme")
      assert Content.get_graphql_endpoint_by(@site, name: "nonexistent") == nil
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
