# Beacon CMS — SEO & LLM Visibility: Research Brief

## Who We Are

**Beacon** is an open-source content management system built on Elixir and Phoenix LiveView. It is a headless-capable CMS that stores pages, layouts, and components in PostgreSQL and renders them at runtime through a LiveView pipeline. Beacon is not a static site generator — it serves dynamic, server-rendered pages with LiveView's WebSocket-based updates.

**DockYard** is the company behind Beacon. DockYard is a digital product consultancy that builds custom software. dockyard.com runs on Beacon with ~952 pages including ~884 blog posts. DockYard's site is the primary production deployment of Beacon and serves as the proving ground for all SEO features.

**Beacon LiveAdmin** is the companion admin interface for Beacon, also open-source. It provides a browser-based UI for managing pages, layouts, components, and SEO settings.

## What We've Built So Far

We have just completed a comprehensive SEO meta tag system for Beacon across six implementation phases. This document describes what exists today, what we plan to build next, and the research questions we need answered to make the best product decisions.

### Current SEO Infrastructure (Implemented)

#### Phase 1: Core Meta Tag Engine

**Meta tag deduplication.** Beacon renders meta tags from three sources: page-level, layout-level, and site-level defaults. Previously these were concatenated without deduplication, meaning a page and its layout could both emit `og:title`, producing duplicate tags. We implemented `deduplicate_meta_tags/2` which keys on the `property`, `name`, or `http-equiv` attribute. Priority cascade: page tags override layout tags override site defaults. The `beacon_meta_tags` assign in LiveView can override everything.

**Title template system.** Site config accepts `title_template` (e.g., `"{page_title} | {site_name}"`) and `site_name`. The template is applied in `render_page_title/1` after Liquid-style snippet interpolation. Pages can override with `extra["title_template"]` set to `"none"` (no template) or a custom template string.

**Canonical URL auto-generation.** Every page gets a `<link rel="canonical">` tag. Auto-generated from the site's public URL + page path. Pages can override via the first-class `canonical_url` field or `extra["canonical_url"]`. Rendered in the `<head>` via `render_canonical_link/1`.

**Raw schema (JSON-LD) interpolation.** The `raw_schema` field stores arbitrary JSON-LD as an array of maps. Previously rendered as-is. Now supports `{{ page.title }}`, `{{ page.path }}`, `{{ page.description }}`, and `{% helper 'name' %}` snippet interpolation within JSON-LD string values. `interpolate_raw_schema/3` recursively walks the data structure, applying `render_snippet/2` to strings while passing through numbers, booleans, and nested structures.

**Per-page robots meta tag.** Pages can set a `robots` field (or `extra["robots"]`) to control indexing. Values like `"noindex, nofollow"` emit a `<meta name="robots">` tag. Absence means default browser/crawler behavior (index, follow). Rendered via `render_robots_meta/1`.

#### Phase 2: Structured SEO Fields

**Migration V010** adds 8 columns to `beacon_pages` (and snapshots): `meta_description`, `canonical_url`, `robots`, `og_title`, `og_description`, `og_image`, `twitter_card`, `page_type`. Adds 2 columns to `beacon_layouts` (and snapshots): `default_og_image`, `default_twitter_card`.

**Auto-generated meta tags from first-class fields.** `build_seo_meta_tags/3` generates meta tags from the first-class fields: `description`, `og:title`, `og:description`, `og:image` (with cascade: page -> layout -> config), `og:image:width`, `og:image:height`, `og:type` (article vs website based on `page_type`), `og:url`, `og:site_name`, `twitter:card` (cascade), `twitter:site`, `fb:app_id`. Only activates when at least one SEO field is configured (opt-in guard prevents empty tag generation on unconfigured sites).

**Site-level config fields:** `site_name`, `title_template`, `default_og_image`, `default_og_image_dimensions` (tuple `{width, height}`), `default_twitter_card`, `twitter_site`, `fb_app_id`, `organization` (map), `search_action_url_template`, `feeds` (list of maps), `index_now_enabled`, `index_now_key`.

#### Phase 3: Automatic JSON-LD

**`Beacon.SEO.JsonLd` module** auto-generates structured data:
- `Article` schema when `page_type == "article"` — includes headline, description, image, datePublished, dateModified, url, publisher.
- `BreadcrumbList` schema from URL path segments. `/blog/authors/john` produces 4 items (Home, Blog, Authors, John). Last item has no URL (current page). Segment names are title-cased with hyphens converted to spaces.
- `Organization` schema on root page when `config.organization` is set. Includes name, url, logo, sameAs.
- `WebSite` schema on root page when `config.site_name` is set. Includes optional SearchAction with `config.search_action_url_template`.

**Merge logic.** Auto-generated schemas are merged with manual `raw_schema` entries. Manual entries take precedence — if a manual schema has the same `@type`, the auto-generated one is suppressed. This allows authors to override any auto-generated schema while still benefiting from the ones they don't override.

#### Phase 4: Enhanced Rendering

- `og:image:width` and `og:image:height` emitted when an OG image is present and `default_og_image_dimensions` is configured.
- `render_pagination_links/1` for `<link rel="prev/next">` on paginated pages (via `extra["pagination_prev"]` and `extra["pagination_next"]`).
- `render_feed_links/1` for RSS/Atom feed discovery links from `config.feeds`.

#### Phase 5: Admin UI (Beacon LiveAdmin)

**SEO tab** in the page editor with sections for Search Appearance, Social Sharing, and Advanced. Fields: `meta_description` (textarea + character counter 0/160), `robots` (dropdown), `page_type` (dropdown: website/article/product), `og_title` (input + counter 0/60), `og_description` (textarea + counter 0/160), `og_image` (URL input), `twitter_card` (dropdown), `canonical_url` (input with auto-generation hint).

**SERP preview** — live-updating Google search result mockup with blue title (truncated to 60 chars), green URL path, gray description (truncated to 160 chars).

**Social preview** — Facebook/LinkedIn card preview showing OG image at 1.91:1 aspect ratio, title, description, domain.

**Character counters** — color-coded (gray=empty, green=under limit, yellow=approaching, red=over).

**SEO score** — traffic-light indicator computed from 12 checks totaling 100 points. Has title (10), title length <=60 (10), has description (10), description length <=160 (10), has OG image (15), has OG title (5), has OG description (5), has canonical URL (10), has structured data (10), has robots (5), page type set (5), has twitter card (5). Green >=80%, Yellow 40-80%, Red <40%.

**Schema editor enhancements** — template insertion buttons for Article, FAQPage, Product, HowTo schema types. Each inserts a pre-filled JSON-LD template into the Monaco editor.

**SEO audit page** — site-wide dashboard showing total pages, counts by score category (good/needs work/poor), missing description count, missing OG image count. Table listing all pages sorted by score with path, title, issues (as red badges), and "Fix" link to the SEO tab.

#### Phase 6: Advanced Features

**Sitemap enhancements** — per-page controls via `extra` map: `sitemap_exclude` (boolean), `sitemap_changefreq` (daily/weekly/monthly), `sitemap_priority` (0.1-1.0). Sitemap controller filters excluded pages and conditionally includes changefreq/priority in the XML.

**IndexNow integration** — `Beacon.SEO.IndexNow` with `notify/2`, `notify_batch/2`, and `on_publish/1` lifecycle hook. Uses `:httpc` (Erlang stdlib) for HTTP requests to `api.indexnow.org`. Config-driven: `index_now_enabled` and `index_now_key`.

**OG image generator behaviour** — `Beacon.SEO.OGImageGenerator` with `generate/2` and `cache_key/2` callbacks. Allows custom implementations (SVG-to-PNG, external service, etc.).

### Current dockyard.com SEO State

All 952 pages have been populated with SEO fields via migration:
- 926 pages have `meta_description` (97%)
- 952 pages have `canonical_url` (100%)
- 952 pages have `og_image` (100% — blog posts use their illustration with `-og.png` suffix, others get the default narwin image)
- 884 pages are `page_type: "article"` (blog posts)
- 14 pages have `robots: "noindex, nofollow"` (test/draft pages)
- All pages have `twitter_card: "summary_large_image"`

The site uses snippet helpers for dynamic OG content: `meta_tag_og_type` (article vs website), `meta_tag_og_image` (illustration with -og.png suffix or fallback), `meta_tag_og_image_alt` (alt text from illustration or filename).

Default meta tags configured in `config/runtime.exs` include: description, og:title, og:url, og:type, og:image, og:description, og:site_name, og:locale, twitter:card, twitter:site, og:image:alt.

---

## What We Plan to Build Next

Based on extensive research into LLM search optimization, traditional SEO best practices, and competitive CMS analysis, these are the features we plan to add to Beacon:

### 1. Content Freshness Infrastructure

**Why:** Content updated within 30 days gets 3.2x more AI citations (ConvertMate, 80M citations). Freshness is 6% of Google's ranking algorithm (First Page Sage 2025), and pages updated yearly gain an average of 4.6 positions.

**What we want to build:**
- A `date_modified` field on Page, separate from `updated_at`. Only bumped on substantive edits, not auto-saves or typo fixes.
- Admin UI: "Mark as substantially updated" action that bumps `date_modified`.
- Sitemap `lastmod` sourced from `date_modified` (not `updated_at`).
- Dashboard: stale content detection — pages not updated in 90+ days, sorted by importance.
- Proper `datePublished`/`dateModified` in Article JSON-LD (already partially implemented, needs the manual trigger integration).

**Open questions:**
- How should we define "substantive" edit vs. trivial edit? Should the CMS detect this automatically (diff-based threshold) or require explicit author action?
- Should we integrate with Google Search Console API to correlate freshness with actual ranking changes?
- What's the right frequency for freshness reminders? Quarterly? Based on content type?

### 2. Automatic Redirect Management

**Why:** No mainstream CMS handles this well without plugins. WordPress requires Yoast Premium or Redirection plugin. When a page's URL changes and there's no redirect, all existing links (external backlinks, social shares, bookmarks) break. Google confirms 301s pass ~100% of link equity.

**What we want to build:**
- A `beacon_redirects` table: `source_path`, `destination_path`, `status_code` (301/302/307/308), `is_regex`, `priority`, `hit_count`, `created_at`, `expires_at`.
- A Phoenix Plug early in the endpoint pipeline that checks ETS-cached redirects on every request (O(1) lookup for exact matches, ordered regex evaluation for patterns).
- Automatic 301 creation when a page's path changes at publish time.
- Redirect chain detection and flattening at creation time (if A→B and B→C, auto-flatten to A→C and B→C).
- Circular redirect prevention.
- Admin UI: redirect list, chain visualization, 404 log with "create redirect" suggestion, stale redirect cleanup.

**Open questions:**
- Should regex redirects be supported from the start, or only exact-match redirects?
- Where should the Plug sit in the pipeline? Before or after Beacon's site routing?
- How should multi-site redirects work? Per-site redirect tables, or global?
- Should we serve the IndexNow key file (`/{key}.txt`) through the same redirect infrastructure?

### 3. AI Crawler Management

**Why:** AI crawlers now account for ~20% of Googlebot's request volume. GPTBot requests increased 305% YoY (Cloudflare 2025). The distinction between "training" crawlers and "search/citation" crawlers is critical — sites should allow search crawlers for visibility while blocking training crawlers to protect content.

**What we want to build:**
- Configurable robots.txt with AI crawler presets built into Beacon's ProxyEndpoint.
- Two modes: "Allow search, block training" (recommended default) and "Block all AI."
- The "allow search, block training" preset would:
  - Allow: `OAI-SearchBot`, `Claude-SearchBot`, `PerplexityBot`, `Amzn-SearchBot`, `DuckAssistBot`, `MistralAI-User`, `meta-webindexer`
  - Block: `GPTBot`, `anthropic-ai`, `ClaudeBot`, `Google-Extended`, `Applebot-Extended`, `CCBot`, `Bytespider`, `Meta-ExternalAgent`, `meta-externalagent`, `Meta-ExternalFetcher`, `Amazonbot`, `cohere-ai`, `cohere-training-data-crawler`, `DeepSeekBot`, `Diffbot`, `PetalBot`, `img2dataset`, `TikTokSpider`
- Site-level config field: `ai_crawler_policy` — `:allow_search` | `:block_all` | `:allow_all` | `:custom`
- For `:custom`, accept a list of `{user_agent, :allow | :block}` tuples.

**Open questions:**
- The AI crawler landscape changes monthly. How should we maintain the User-Agent list? Hardcoded with regular updates? Fetch from a community-maintained list (github.com/ai-robots-txt/ai.robots.txt has 196 agents)?
- Should we also emit `X-Robots-Tag: noai, noimageai` headers? These are recognized by some crawlers but not standardized.
- Cloudflare's `Content-Signal` directive (`search=yes, ai-train=no`) is deployed on 3.8M+ domains. Should Beacon emit this header?
- Should we provide per-page AI crawler control (via meta robots) in addition to site-level robots.txt?

### 4. FAQPage Schema Builder

**Why:** Pages with FAQPage schema achieve 41% citation rate in AI Overviews vs 15% without (Relixir, 2.7x lift). FAQ format aligns with how LLMs were trained (SQuAD, Natural Questions datasets). 78% of AI-generated answers use list formats.

**What we want to build:**
- A dedicated FAQ section on pages — either a new `faq_items` field (array of `%{question: "", answer: ""}`) or stored in the `extra` map.
- Auto-generate FAQPage JSON-LD when FAQ items are present.
- Merge with existing Article/BreadcrumbList schemas (combined schema = 2x more citations per BrightEdge).
- Admin UI: simple Q&A pair editor in the SEO tab with add/remove/reorder.
- Guidance: optimal answer length is 40-60 words per answer.

**Open questions:**
- Should FAQ items be a first-class schema field or stored in `extra`?
- Should the FAQ section be rendered visually on the page (collapsible Q&A), or only exist as JSON-LD?
- Google now restricts FAQ rich results to government and health sites. The schema still improves AI citations — should we communicate this to authors?
- Should we validate that FAQ schema `name` values match visible content on the page (Google's requirement)?

### 5. Author Management & Person Schema (E-E-A-T)

**Why:** 96% of Google AI Overview citations come from sources with strong E-E-A-T signals. Author authority is a key trust signal. LLMs evaluate author information when selecting citations.

**What we want to build:**
- A `beacon_authors` table: `name`, `slug`, `bio`, `job_title`, `avatar_url`, `credentials` (text), `same_as` (array of external profile URLs like LinkedIn, Twitter, GitHub).
- Optional `author_id` foreign key on Page.
- Auto-generate `Person` JSON-LD on author archive pages with: name, jobTitle, description, image, knowsAbout, sameAs, worksFor.
- Link Article schema to author Person entity via `@id` references.
- Admin UI: author management panel, author picker on page editor.

**Open questions:**
- Should authors be a Beacon-level concept (in the core library) or a site-level concept (configured per deployment)?
- How should author pages work? Auto-generated from the author record, or manually created pages that link to the author?
- Should we support multiple authors per page?
- For dockyard.com specifically: should we pull author data from the existing `employees` table or create separate author records?

### 6. Internal Link Graph Analysis

**Why:** Orphan pages (no inbound internal links) are invisible to both Google and LLMs. Internal linking is how search engines discover and distribute authority across a site.

**What we want to build:**
- A `beacon_internal_links` table populated at publish time by parsing rendered HTML: `source_page_id`, `target_page_id`, `target_path`, `anchor_text`.
- Delete and rebuild links for a page on every publish.
- Orphan page detection: published pages with zero inbound links.
- Broken link detection: links to paths that don't match any published page.
- Admin dashboard: orphans list, broken links list, hub pages (most outbound links), authority pages (most inbound links).

**Open questions:**
- Should we parse the raw template (Beacon syntax) or the rendered HTML output?
- How do we handle dynamic links (links generated from data bindings like `{{ post.post_path }}`)?
- Should link graph analysis be real-time (on every publish) or periodic (nightly batch)?
- How should we handle links in layout templates (header/footer navigation)?

### 7. llms.txt and llms-full.txt Auto-Generation

**Why:** ~844K sites have adopted llms.txt. While no LLM provider has confirmed they use it for search citations, it has genuine value for developer tools (Cursor, Claude Code, VS Code extensions). Mintlify reports llms-full.txt is accessed 2x more than llms.txt. The spec was proposed by Jeremy Howard (Answer.AI) and co-developed with Anthropic (for llms-full.txt). Adopted by Anthropic docs, Cloudflare, Stripe, Vercel.

**What we want to build:**
- `/llms.txt` endpoint: Markdown index with H1 site name, blockquote description, H2 sections grouping pages by path prefix, links with descriptions.
- `/llms-full.txt` endpoint: All published page content concatenated as Markdown.
- Per-page `.md` endpoint: `/{page-path}.md` returns clean Markdown of the page content.
- Served with `Content-Type: text/markdown; charset=utf-8` and `X-Robots-Tag: noindex`.
- Config toggle: `llms_txt_enabled: true`.
- Regenerate on publish events, cache result.

**Open questions:**
- For large sites (900+ pages like dockyard.com), should we limit what goes into llms-full.txt? Cloudflare's is 41.5 MB. Should there be a size limit?
- Should we support Cloudflare's hierarchical approach (per-section llms.txt files)?
- How should we convert Beacon templates to clean Markdown? Strip all HTML? Use a Markdown converter?
- Should llms.txt include page descriptions? Or just titles and URLs?
- SE Ranking's study of 300K domains found llms.txt "adds noise" to citation prediction models. Should we position this feature as a developer-tools feature rather than an SEO feature?

---

## Research Context: The LLM Search Landscape

### How LLMs Choose What to Cite

Each platform uses different citation logic:

**ChatGPT** — Strongly favors authoritative, encyclopedic sources. Wikipedia = 7.8% of total citations. ~90% of citations come from pages ranked #21+ in Google. Content from the first 30% of a page accounts for 44% of citations ("ski ramp" effect). Statistical facts increase citation likelihood by 22%, direct quotations by 37%.

**Google AI Overviews** — Balanced across source types. Reddit 2.2%, YouTube 1.9%, Quora 1.5%. Favors diversified cross-platform presence. Pulls disproportionately from pages with schema markup.

**Perplexity** — Prioritizes community-generated content. Reddit commands 6.6% of citations. Emphasizes real-time content.

**Key findings from large-scale studies:**
- Only ~11% of domains are cited by BOTH ChatGPT and Perplexity (extreme platform fragmentation)
- ~30 domains capture 67% of citations within any given topic
- 58% of cited URLs appear for only one prompt then vanish
- The top 5% of pages answer 10+ unique prompts
- Cited content has average entity density of 20.6% vs 5-8% for non-cited pages
- Content updated within 30 days earns ~3.2x more AI citations

### AI Crawler Ecosystem

AI crawlers now account for ~20% of Googlebot's request volume. The ecosystem has split into training crawlers and search/citation crawlers:

**Training crawlers** (collect data for model training): GPTBot, anthropic-ai/ClaudeBot, Google-Extended, Applebot-Extended, CCBot, Meta-ExternalAgent, Amazonbot, Bytespider, cohere-ai

**Search/citation crawlers** (fetch content for real-time answers): OAI-SearchBot, Claude-SearchBot, ChatGPT-User, PerplexityBot, Perplexity-User, Amzn-SearchBot, DuckAssistBot, MistralAI-User, BingBot (dual-purpose, no separation possible)

**Notable bad actors:** xAI/Grok confirmed spoofing iPhone user-agents. DeepSeekBot doesn't reliably identify itself. Perplexity documented using stealth crawlers that modify user agents to evade blocks.

**OpenAI's GPTBot/OAI-SearchBot sharing:** If a site allows both, OpenAI may use results from one crawl for both purposes. Blocking GPTBot while allowing OAI-SearchBot is the recommended configuration for "search visibility without training."

### llms.txt Standard

Proposed September 2024 by Jeremy Howard (Answer.AI). Markdown file at `/llms.txt` providing an LLM-friendly content index. Format: H1 heading (required), optional blockquote summary, H2-delimited sections with link lists.

**Adoption:** ~844K implementations. Adopted by Anthropic docs, Cloudflare, Stripe, Vercel, Cursor. SE Ranking found 10.13% adoption across 300K domains.

**Criticism:** Google's John Mueller compared it to the abandoned keywords meta tag. Google's Gary Illyes stated Google does not support it. SE Ranking's machine learning analysis found removing llms.txt improved citation prediction accuracy. Redocly's testing showed llms.txt files are "basically never" requested by AI crawlers.

**Practical value:** Developer tools (Cursor, Claude Code) genuinely use llms-full.txt to load documentation context. Mintlify reports 2x more access to llms-full.txt than llms.txt. This is a developer-tools feature, not a search feature.

### Content Freshness Data

**Google's December 2025 core update** specifically refined distinction between substantive content changes and cosmetic updates. Sites that changed dates without meaningful content updates received trustworthiness signal reduction.

**Freshness signals Google uses:** Structured data (datePublished/dateModified), visible on-page dates, sitemap lastmod, HTTP Last-Modified header, crawl diffing (detecting actual content changes), Query Deserves Freshness (QDF) for trending topics.

**Freshness impact on rankings:** 6% of Google's ranking algorithm (First Page Sage 2025, up from <1% a few years ago). Pages updated annually gain average 4.6 positions.

**Freshness impact on LLM citations:** Content <30 days old gets 3.2x more citations (ConvertMate, 80M citations). AI-cited content is 25.7% fresher than organic-ranked content (Ahrefs, 17M URLs). 76.4% of ChatGPT's most-cited pages were updated in the last 30 days.

### E-E-A-T and Author Authority

**E-E-A-T is NOT a direct ranking factor.** Google's Danny Sullivan: "Our systems aren't looking for E-E-A-T. Our raters are using that to see if our systems are working well." Quality raters evaluate pages using E-E-A-T criteria, and those evaluations tune the ranking algorithms.

**Person schema for authors** should include: name, jobTitle, description, image, alumniOf, knowsAbout, sameAs (LinkedIn, Twitter, GitHub), worksFor, hasCredential, award.

**Organization schema** most impactful properties: sameAs (Wikipedia, Wikidata = strongest verification), foundingDate, numberOfEmployees, address, logo, iso6523Code/taxID/duns.

### FAQPage Schema Impact

**Relixir study (50 sites):** 41% citation rate with FAQPage schema vs 15% without (2.7x).
**BrightEdge:** 44% increase in AI search citations with structured data and FAQ blocks.
**Growth Marshal (730 citations):** Attribute-rich schema 61.7% citation rate, no schema 59.8%, generic schema 41.6%. Generic schema actually underperformed no schema — implementation quality matters more than presence.

**Google restriction (2026):** FAQ rich results in SERPs are now restricted to government and health sites. However, the schema still improves AI citation rates and content comprehension.

**Optimal FAQ format:** Question-led H2 headings matching how people phrase queries. 40-60 word answers per question. Self-contained, independently extractable answer blocks.

### Structured Data Effectiveness

**Microsoft Bing confirmed (March 2025, SMX Munich):** Schema markup helps Bing's LLMs understand content.
**Data World study:** GPT-4 goes from 16% to 54% correct responses when content has structured data.
**Combined schema (3-4 types):** ~2x more citations than single schema type (BrightEdge).

**Priority order:** FAQPage (highest impact), Article/BlogPosting, Organization (with Wikipedia/Wikidata sameAs), Person (author authority), HowTo, BreadcrumbList.

### Redirect Management Landscape

**WordPress:** Requires Yoast Premium or Redirection plugin for auto-redirect on slug change. Core only handles simple post slug changes.
**Shopify:** Built-in checkbox on URL change. No regex support.
**TYPO3:** Most sophisticated built-in system — auto-creates redirects with cascading child page updates.

**Performance:** Each redirect hop adds 50-300ms. Google follows up to 10 hops but recommends <5. Mixed redirect types in chains create conflicting canonical signals.

**Link equity:** Google confirmed 301s pass ~100% of link equity (same as a regular link). No PageRank dilution from redirects. Redirects should be maintained for at least 1 year.

### Internal Linking

**Orphan page detection:** Compare BFS traversal from homepage against all published page URLs. Pages not reachable = orphans.

**Topic clustering:** Pillar + cluster architecture drives 30% more organic traffic, rankings persist 2.5x longer. Bidirectional linking between pillar and cluster pages creates topical authority signals.

**Link graph storage:** Adjacency list in a database table (`internal_links`), populated at publish time by parsing rendered HTML. Enables efficient queries for orphans, broken links, hub pages, and authority pages.

---

## Technical Architecture

### Elixir/Phoenix/LiveView Stack

Beacon is built on:
- **Elixir** — functional language on the BEAM VM
- **Phoenix Framework** — web framework with routing, controllers, channels
- **Phoenix LiveView** — server-rendered interactive UI over WebSocket
- **Ecto** — database wrapper with migrations, schemas, changesets
- **PostgreSQL** — primary database
- **ETS** — in-memory key-value store for runtime caching (manifests, ASTs, redirects)

### Rendering Pipeline

1. Request arrives at Phoenix endpoint
2. Beacon's router matches the path to a page
3. Page manifest (title, description, meta_tags, raw_schema, SEO fields) loaded from ETS
4. Page template (stored as platform-agnostic AST) rendered via `LiveViewCompiler`
5. Layout template wrapped around page content with `inner_content` slot
6. `<head>` section assembled by `Beacon.Web.Layouts` module: meta tags, robots, canonical link, JSON-LD, title, resource links, pagination links, feed links, CSS, JS
7. HTML sent to browser; LiveView WebSocket maintains connection for updates

### Data Flow for SEO

```
Page created/updated in admin
  -> Ecto changeset validates SEO fields
  -> Page stored in PostgreSQL
  -> Page published -> snapshot created
  -> RuntimeRenderer.publish_page() stores manifest in ETS
  -> Manifest includes: title, description, meta_tags, raw_schema, 
     meta_description, canonical_url, robots, og_title, og_description,
     og_image, twitter_card, page_type, inserted_at, updated_at, extra
  -> Layout published separately with: meta_tags, resource_links,
     default_og_image, default_twitter_card
  -> On request: Beacon.Web.Layouts assembles <head> from manifest + layout + config
  -> JSON-LD auto-generated by Beacon.SEO.JsonLd.build() and merged with manual raw_schema
  -> All meta tag values interpolated through Solid (Liquid) template engine
```

### Configuration

Site-level SEO config lives in the Beacon config struct, typically set in `config/runtime.exs`:

```elixir
config :beacon, :sites, [
  [
    site: :my_site,
    endpoint: MyAppWeb.Endpoint,
    router: MyAppWeb.Router,
    # SEO config
    site_name: "My Site",
    title_template: "{page_title} | {site_name}",
    default_og_image: "https://example.com/default-og.jpg",
    default_og_image_dimensions: {1200, 630},
    default_twitter_card: "summary_large_image",
    twitter_site: "@mysite",
    fb_app_id: "123456789",
    organization: %{
      name: "My Company",
      logo: "https://example.com/logo.png",
      url: "https://example.com",
      same_as: ["https://linkedin.com/company/mycompany", "https://twitter.com/mycompany"]
    },
    search_action_url_template: "https://example.com/search?q={search_term_string}",
    feeds: [%{url: "/feed.xml", title: "Blog", type: "application/rss+xml"}],
    index_now_enabled: true,
    index_now_key: "my-indexnow-key",
    # ... other beacon config
  ]
]
```

---

## Questions for Deep Research

We want a comprehensive analysis that helps us make the best product decisions. Specific questions:

1. **Content freshness: automatic detection vs manual trigger.** Is there a reliable algorithmic approach to distinguish substantive edits from trivial ones? (e.g., diff-based: >10% content change = substantive). Or is manual author action the only reliable approach? What do other CMS platforms do?

2. **Redirect implementation: Plug placement and performance.** In a Phoenix/LiveView application, where should the redirect Plug sit? Before the router? After? What are the performance implications of checking redirects on every request? How large can the redirect table get before ETS lookup performance degrades?

3. **AI crawler list maintenance.** The ai-robots-txt community project tracks 196 user agents. New agents appear monthly. What's the best strategy for maintaining this list in a CMS? Ship a static list and update with releases? Fetch from a remote list periodically? Let site operators customize?

4. **FAQPage schema: rendering vs metadata-only.** Should FAQ items be rendered as visible content on the page, or only exist as JSON-LD metadata? Google requires FAQ schema to match visible content. But rendering FAQ sections changes the page design. What's the best UX for content editors?

5. **Author management: core vs extension.** Should the author concept live in Beacon core (schema, admin UI, JSON-LD) or as an optional extension/package? Not all Beacon deployments need authors. But making it core ensures consistency and enables auto-generated Person schema.

6. **llms.txt value proposition.** Given the negative evidence from SE Ranking (adds noise to citation prediction) and Google's explicit rejection, should we invest engineering effort in llms.txt? Or is the developer-tools use case (Cursor, Claude Code) sufficient justification? What's the cost-benefit?

7. **Link graph scalability.** For a site with 1000+ pages, what's the performance impact of rebuilding the link graph on every publish? Should we parse raw templates or rendered HTML? How do we handle dynamically-generated links from data bindings?

8. **Structured data quality vs quantity.** The Growth Marshal study found generic schema underperforms no schema (41.6% vs 59.8% citation rate). How should we ensure auto-generated schema is attribute-rich rather than generic? What's the minimum set of populated fields that makes schema helpful rather than harmful?

9. **Multi-platform citation optimization.** Only 11% of domains are cited by both ChatGPT and Perplexity. Should Beacon's SEO tools help site operators optimize for specific AI platforms? Or is the overlap too small to warrant platform-specific strategies?

10. **Content structure enforcement.** Research shows answer-first content patterns, question-led headings, and 40-80 word answer blocks increase LLM citations. Should a CMS actively enforce or suggest these patterns? At what point does content structure guidance become prescriptive and limit creative freedom?

11. **Competitive positioning.** How should Beacon position itself against WordPress+Yoast, Contentful, Sanity, and Strapi on SEO? What features would be genuine differentiators vs table stakes? Is "first CMS with built-in LLM search optimization" a defensible market position?

12. **Measurement and feedback loops.** How should Beacon help site operators measure whether SEO changes are working? Integration with Google Search Console API? AI citation monitoring via Otterly.AI or similar? Built-in analytics? What data should be surfaced in the admin?
