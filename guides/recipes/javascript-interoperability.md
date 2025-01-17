# JavaScript interoperability

Beacon provides support for custom client-side JavaScript via LiveView's [JS Hooks](https://hexdocs.pm/phoenix_live_view/js-interop.html#client-hooks-via-phx-hook).

Hooks are blocks of custom JS code which run when an element in a Beacon template reaches a specific
stage of its lifecycle.  There are six possible stages which you can use:

  * `mounted` - the element has been added to the DOM and its server
    LiveView has finished mounting
  * `beforeUpdate` - the element is about to be updated in the DOM.
    *Note*: any call here must be synchronous as the operation cannot
    be deferred or cancelled.
  * `updated` - the element has been updated in the DOM by the server
  * `destroyed` - the element has been removed from the page, either
    by a parent update, or by the parent being removed entirely
  * `disconnected` - the element's parent LiveView has disconnected from the server
  * `reconnected` - the element's parent LiveView has reconnected to the server

To add code to one or more of these, first go into your BeaconLiveAdmin dashboard and navigate to the 
"JS Hooks" section.  Create a new hook with the name of your choice, and you will see empty code blocks
for each of the above callbacks.  For an example, let's add a log message to output to the console when
our page's logo is mounted:

```javascript
// In mounted()
console.log("logo mounted!")
```

Then in the page's template, add a `phx-hook` attr to the desired element:
```html
<div id="logo" phx-hook="MyHookName">
  <img ...>
</div>
```

`MyHookName` should be replaced with whatever name you chose for your hook.  Also note the element
must have an `id` attr defined.

With these changes saved and the page published, you can open that page in your browser and should see
`logo mounted!` in the javascript console.