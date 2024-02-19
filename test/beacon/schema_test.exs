defmodule Beacon.SchemaTest do
  use ExUnit.Case, async: true

  alias Beacon.Schema

  test "validate_path/1" do
    assert {:error, _} = Schema.validate_path(nil)
    assert {:error, _} = Schema.validate_path("")
    assert {:error, _} = Schema.validate_path("*")
    assert {:error, _} = Schema.validate_path(":")
    assert {:error, _} = Schema.validate_path(":/foo")
    assert {:error, _} = Schema.validate_path("/foo:")
    assert {:error, _} = Schema.validate_path("/foo:/bar")
    assert {:error, _} = Schema.validate_path("/foo/:123")
    assert {:error, _} = Schema.validate_path("/:123/bar")
    assert {:error, _} = Schema.validate_path("/:foo-bar")
    assert {:error, _} = Schema.validate_path("/foo bar")
    assert {:error, _} = Schema.validate_path("/foo?q=bar")
    assert {:ok, _} = Schema.validate_path("/")
    assert {:ok, _} = Schema.validate_path("/foo")
    assert {:ok, _} = Schema.validate_path("/FOO")
    assert {:ok, _} = Schema.validate_path("/foo/bar")
    assert {:ok, _} = Schema.validate_path("/foo/:bar")
    assert {:ok, _} = Schema.validate_path("/:foo/bar")
    assert {:ok, _} = Schema.validate_path("/foo/123")
    assert {:ok, _} = Schema.validate_path("/123/bar")
    assert {:ok, _} = Schema.validate_path("/foo_bar")
    assert {:ok, _} = Schema.validate_path("/:foo_bar")
    assert {:ok, _} = Schema.validate_path("/foo-bar")
    assert {:ok, _} = Schema.validate_path("/foo:bar")
    assert {:ok, _} = Schema.validate_path("/foo//bar")
    assert {:ok, _} = Schema.validate_path("/api/v:version/pages/:id")
    assert {:ok, _} = Schema.validate_path("/pages/he:page/*rest")
  end
end
