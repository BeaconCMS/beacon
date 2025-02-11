# Libraries in JS Hooks

In this guide we'll load a JS library from CDN to use in JS Hooks.

Beacon supports user-defined JS Hooks created and maintained in the Beacon LiveAdmin interface,
and usually we need to load and call external JavaScript libraries in those hooks.

Currently it's not possible to directly `import` libraries defined in your application's `package.json` file,
but an alternative is to load libraries from a CDN as https://unpkg.com

Let's start by editing a layout or a page where you want to load a library.
For this guide we'll use [Tippy.js](https://atomiks.github.io/tippyjs) as example,
so include these lines in the template:

```heex
<script src="https://unpkg.com/@popperjs/core@2"></script>
<script src="https://unpkg.com/tippy.js@6"></script>
```

Those scripts will make `window.tippy` available in your page,
which you can then use in your JS Hook. Let's create it now.

Go to the JS Hooks page in Admin, create a new hooke named `tippy`
and input the following code:

```js
export const tippy = {
  mounted() {
    window.tippy(this.el, {content: 'My message'})
  }
}
```

Now whenever you want to use that hook, just include the `phx-hook="tippy"` property in an element,
either in the page you loaded the scripts or any page that use the layout that contains those scripts.
For example in a button to show a tooltip in a button:

```heex
<button id="sign-up" phx-hook="tippy">Sign Up</button>
```
