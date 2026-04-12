defmodule Beacon.GraphQL.IntrospectionTest do
  use ExUnit.Case, async: true

  alias Beacon.GraphQL.Introspection

  describe "parse_sdl/1" do
    test "parses queries from SDL" do
      sdl = """
      type Query {
        posts(limit: Int!, offset: Int): [Post!]!
        post(slug: String!): Post
      }

      type Post {
        id: ID!
        title: String!
        body: String
        author: Author
      }

      type Author {
        id: ID!
        name: String!
      }
      """

      schema = Introspection.parse_sdl(sdl)

      assert length(schema["queries"]) == 2
      assert Enum.any?(schema["queries"], &(&1["name"] == "posts"))
      assert Enum.any?(schema["queries"], &(&1["name"] == "post"))

      posts_query = Enum.find(schema["queries"], &(&1["name"] == "posts"))
      assert length(posts_query["args"]) == 2

      limit_arg = Enum.find(posts_query["args"], &(&1["name"] == "limit"))
      assert limit_arg["type"]["kind"] == "NON_NULL"
    end

    test "parses mutations from SDL" do
      sdl = """
      type Mutation {
        createPost(title: String!, body: String!): Post!
        deletePost(id: ID!): Boolean!
      }

      type Post {
        id: ID!
        title: String!
      }
      """

      schema = Introspection.parse_sdl(sdl)

      assert length(schema["mutations"]) == 2
      assert Enum.any?(schema["mutations"], &(&1["name"] == "createPost"))
    end

    test "parses types (excluding Query/Mutation)" do
      sdl = """
      type Query {
        user: User
      }

      type User {
        id: ID!
        name: String!
        email: String
      }
      """

      schema = Introspection.parse_sdl(sdl)

      assert length(schema["types"]) == 1
      user_type = hd(schema["types"])
      assert user_type["name"] == "User"
      assert length(user_type["fields"]) == 3
    end

    test "handles NON_NULL types" do
      sdl = """
      type Query {
        user(id: ID!): User!
      }

      type User {
        id: ID!
      }
      """

      schema = Introspection.parse_sdl(sdl)
      query = hd(schema["queries"])
      assert query["type"]["kind"] == "NON_NULL"
      assert query["type"]["ofType"]["name"] == "User"
    end

    test "handles LIST types" do
      sdl = """
      type Query {
        users: [User]
      }

      type User {
        id: ID!
      }
      """

      schema = Introspection.parse_sdl(sdl)
      query = hd(schema["queries"])
      assert query["type"]["kind"] == "LIST"
    end

    test "returns empty queries for schema without Query type" do
      sdl = """
      type User {
        id: ID!
      }
      """

      schema = Introspection.parse_sdl(sdl)
      assert schema["queries"] == []
      assert schema["mutations"] == []
    end
  end
end
