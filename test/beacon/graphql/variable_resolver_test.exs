defmodule Beacon.GraphQL.VariableResolverTest do
  use ExUnit.Case, async: true

  alias Beacon.GraphQL.VariableResolver

  describe "resolve/4" do
    test "resolves path_param source" do
      bindings = %{"slug" => %{"source" => "path_param", "key" => "slug"}}
      path_params = %{"slug" => "hello-world"}

      result = VariableResolver.resolve(bindings, path_params, %{})
      assert result == %{"slug" => "hello-world"}
    end

    test "resolves query_param source" do
      bindings = %{"page" => %{"source" => "query_param", "key" => "page"}}
      query_params = %{"page" => "2"}

      result = VariableResolver.resolve(bindings, %{}, query_params)
      assert result == %{"page" => "2"}
    end

    test "resolves literal source" do
      bindings = %{"limit" => %{"source" => "literal", "value" => 10}}

      result = VariableResolver.resolve(bindings, %{}, %{})
      assert result == %{"limit" => 10}
    end

    test "resolves query_result source" do
      bindings = %{"authorId" => %{"source" => "query_result", "from" => "author", "path" => "id"}}
      prior = %{"author" => %{"id" => "abc-123"}}

      result = VariableResolver.resolve(bindings, %{}, %{}, prior)
      assert result == %{"authorId" => "abc-123"}
    end

    test "uses default when path_param is missing" do
      bindings = %{"tag" => %{"source" => "path_param", "key" => "tag", "default" => "all"}}

      result = VariableResolver.resolve(bindings, %{}, %{})
      assert result == %{"tag" => "all"}
    end

    test "returns nil for unknown source" do
      bindings = %{"x" => %{"source" => "unknown"}}

      result = VariableResolver.resolve(bindings, %{}, %{})
      assert result == %{"x" => nil}
    end

    test "resolves multiple bindings" do
      bindings = %{
        "slug" => %{"source" => "path_param", "key" => "slug"},
        "limit" => %{"source" => "literal", "value" => 5},
        "page" => %{"source" => "query_param", "key" => "p", "default" => "1"}
      }

      result = VariableResolver.resolve(bindings, %{"slug" => "test"}, %{})
      assert result == %{"slug" => "test", "limit" => 5, "page" => "1"}
    end
  end
end
