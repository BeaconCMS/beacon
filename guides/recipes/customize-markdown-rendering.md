# Customize Markdown Rendering

Markdown pages are rendered using the [Beacon.Template.Markdown](https://hexdocs.pm/beacon/0.1.0-rc.2/Beacon.Template.Markdown.html) module with a set of default options that works for most cases,
but you might want to change how some features work or enable more features. For example, let's suppose you want to generate an ID for every header of the page with the suffix `"topic-"`.

You can do that by changing the `:load_template` lifecycle of `:markdown` in your [site configuration](https://hexdocs.pm/beacon/0.1.0-rc.2/Beacon.html#start_link/1) as the example below:

```elixir
[
  site: :my_site,
  lifecycle: [
    load_template: [
      {:markdown,
        [
          markdown_with_header_ids: &markdown_with_header_ids/2
        ]
      }
    ]
  ]
  # rest ommited for brevity...
]

def markdown_with_header_ids(template, _metadata) do
  template = MDEx.to_html!(markdown, extension: [header_ids: "topic-"])
  {:cont, template}
end
```

But keep in mind this operation will replace the default markdown rendering with the one you provided,
so the only features enabled will be the one you set and the others will take the default value.

For example with this configuration the `:header_ids` extension is enabled but others like tables and autolinks would be turned off.

You can inspect the actual configuration in the [Beacon.Template.Markdown](https://hexdocs.pm/beacon/0.1.0-rc.2/Beacon.Template.Markdown.html) module and also check the [MDEx docs](https://hexdocs.pm/mdex/MDEx.html#to_html/2) for more info.