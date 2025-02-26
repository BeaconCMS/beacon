# Notify Page Published

Let's suppose you want to notify a group of people via email when a page is published and your Phoenix application is already integrated with a mailer.

Beacon provides some lifecycle hooks that you can use to inject custom logic when something happens, in this case, when a page is published the hook `:after_publish_page` is triggered.

You can check out the full documentation and the list of available in the `Beacon.Config` module. This is the spec for the `:after_publish_page` hook:

```elixir
{:after_publish_page, [{identifier :: atom(), fun :: (Content.Page.t() -> {:cont, Content.Page.t()} | {:halt, Exception.t()})}]}
```

It may look a bit complex, but it's quite simple. You need to define a function that receives a `Content.Page.t()` struct and returns either
`{:cont, Content.Page.t()}` to continue the process or `{:halt, Exception.t()}` to stop it. And the identifier is just a unique name for your custom logic.

For our example, the site config would look like:

```elixir
lifecycle: [
  after_publish_page: [
    notify_page_published: &MyApp.CMS.notify_page_published/1
  ]
]
```

And the corresponding function in `MyApp.CMS` module:

```elixir
defmodule MyApp.CMS do
  def notify_page_published(%Beacon.Content.Page{path: path} = page) do
    email =  MyApp.CMS.notify_email(%{path: path})

    case MyApp.Mailer.deliver(email) do
      {:ok, _} ->
        {:cont, page}

      {:error, reason} ->
        message = """
        failed to notify that page #{path} was published

        Got:

          #{inspect(reason)}
        """

        # or use a custom exception
        {:halt, %RuntimeError{message: message}}
    end
  end
end
```