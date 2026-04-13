defmodule Beacon.SEO.AICrawlers do
  @moduledoc """
  Curated, versioned lists of known AI crawler user-agents.

  Lists are categorized into training bots (crawl content to train AI models)
  and search bots (crawl to power AI-assisted search results). Updated with
  each Beacon release.

  ## Configuration

      config :beacon, :sites, [
        [
          site: :my_site,
          ai_crawler_policy: :allow_search,  # :allow_search | :block_all | :allow_all | :custom
          ai_crawler_custom_rules: [],       # [{user_agent, :allow | :block}]
          ...
        ]
      ]
  """

  @version "2026.04"

  @doc "Returns the version of the bot list."
  @spec version() :: String.t()
  def version, do: @version

  @doc "Returns all known AI training bot user-agents."
  @spec training_bots() :: [String.t()]
  def training_bots do
    [
      "GPTBot",
      "anthropic-ai",
      "Claude-Web",
      "ClaudeBot",
      "Google-Extended",
      "Applebot-Extended",
      "CCBot",
      "Bytespider",
      "Meta-ExternalAgent",
      "meta-externalagent",
      "Meta-ExternalFetcher",
      "meta-externalfetcher",
      "Amazonbot",
      "cohere-ai",
      "cohere-training-data-crawler",
      "Diffbot",
      "DeepSeekBot",
      "PetalBot",
      "img2dataset",
      "TikTokSpider",
      "AI2Bot",
      "Ai2Bot-Dolma",
      "ChatGLM-Spider",
      "Scrapy",
      "Timpibot",
      "omgili",
      "omgilibot"
    ]
  end

  @doc "Returns all known AI search/citation bot user-agents."
  @spec search_bots() :: [String.t()]
  def search_bots do
    [
      "OAI-SearchBot",
      "Claude-SearchBot",
      "PerplexityBot",
      "Amzn-SearchBot",
      "DuckAssistBot",
      "MistralAI-User",
      "meta-webindexer"
    ]
  end

  @doc """
  Generates robots.txt directive blocks based on the configured policy.

  Returns a list of strings, each being a complete User-agent/Allow|Disallow block.

  ## Policies

    * `:allow_all` — no AI-specific directives (empty list)
    * `:block_all` — block all known AI bots (training and search)
    * `:allow_search` — block training bots, explicitly allow search bots
    * `:custom` — apply custom per-bot rules from `custom_rules`
  """
  @spec robots_directives(:allow_search | :block_all | :allow_all | :custom, [{String.t(), :allow | :block}]) :: [String.t()]
  def robots_directives(policy, custom_rules \\ [])

  def robots_directives(:allow_all, _custom_rules), do: []

  def robots_directives(:block_all, _custom_rules) do
    (training_bots() ++ search_bots())
    |> Enum.uniq()
    |> Enum.map(&block_directive/1)
  end

  def robots_directives(:allow_search, _custom_rules) do
    block = Enum.map(training_bots() -- search_bots(), &block_directive/1)
    allow = Enum.map(search_bots(), &allow_directive/1)
    block ++ allow
  end

  def robots_directives(:custom, custom_rules) do
    Enum.map(custom_rules, fn
      {user_agent, :block} -> block_directive(user_agent)
      {user_agent, :allow} -> allow_directive(user_agent)
    end)
  end

  defp block_directive(bot), do: "User-agent: #{bot}\nDisallow: /"
  defp allow_directive(bot), do: "User-agent: #{bot}\nAllow: /"
end
