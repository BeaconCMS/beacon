defmodule Beacon.SEO.AICrawlersTest do
  use ExUnit.Case, async: true

  alias Beacon.SEO.AICrawlers

  test "training_bots returns a non-empty list" do
    bots = AICrawlers.training_bots()
    assert is_list(bots)
    assert length(bots) > 10
    assert "GPTBot" in bots
    assert "anthropic-ai" in bots
    assert "Google-Extended" in bots
  end

  test "search_bots returns a non-empty list" do
    bots = AICrawlers.search_bots()
    assert is_list(bots)
    assert length(bots) > 3
    assert "OAI-SearchBot" in bots
    assert "PerplexityBot" in bots
    assert "Claude-SearchBot" in bots
  end

  test "robots_directives :allow_all returns empty" do
    assert AICrawlers.robots_directives(:allow_all) == []
  end

  test "robots_directives :block_all blocks all bots" do
    directives = AICrawlers.robots_directives(:block_all)
    assert length(directives) > 20
    assert Enum.all?(directives, &String.contains?(&1, "Disallow: /"))
    assert Enum.any?(directives, &String.contains?(&1, "GPTBot"))
    assert Enum.any?(directives, &String.contains?(&1, "OAI-SearchBot"))
  end

  test "robots_directives :allow_search blocks training, allows search" do
    directives = AICrawlers.robots_directives(:allow_search)

    block_directives = Enum.filter(directives, &String.contains?(&1, "Disallow"))
    allow_directives = Enum.filter(directives, &String.contains?(&1, "Allow: /"))

    assert length(block_directives) > 10
    assert length(allow_directives) > 3

    # GPTBot should be blocked (training)
    assert Enum.any?(block_directives, &String.contains?(&1, "GPTBot"))
    # OAI-SearchBot should be allowed (search)
    assert Enum.any?(allow_directives, &String.contains?(&1, "OAI-SearchBot"))
  end

  test "robots_directives :custom applies per-bot rules" do
    rules = [{"MyBot", :block}, {"GoodBot", :allow}]
    directives = AICrawlers.robots_directives(:custom, rules)

    assert length(directives) == 2
    assert "User-agent: MyBot\nDisallow: /" in directives
    assert "User-agent: GoodBot\nAllow: /" in directives
  end

  test "version returns a string" do
    assert is_binary(AICrawlers.version())
  end
end
