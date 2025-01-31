# Access Page Info

In order to build pages you might need to access the current site or page information, as query params, path, and so on.

Beacon provides a read-only assign `@beacon` that is available on all templates and also on Elixir code blocks as event handlers.

For example, to access the current page title in a template:

```heex
<h1><%= @beacon.page.title %></h1>
```

See the module [Beacon.Web.BeaconAssigns](https://hexdocs.pm/beacon/Beacon.Web.BeaconAssigns.html) for more info.
