// Beacon Admin
//
// Note:
// 1. run `mix assets.build` to distribute updated static assets
// 2. phoenix js loaded from the host application

import { CodeEditorHook } from "../../deps/live_monaco_editor/priv/static/live_monaco_editor.esm"

let Hooks = {}
Hooks.CodeEditorHook = CodeEditorHook

window.addEventListener("lme:editor_mounted", (ev) => {
  const hook = ev.detail.hook
  const editor = ev.detail.editor.standalone_code_editor
  const eventName = ev.detail.editor.path + "_editor_lost_focus"

  editor.onDidBlurEditorWidget(() => {
    hook.pushEvent(eventName, { value: editor.getValue() })
  })
})

window.addEventListener("beacon_admin:clipcopy", (event) => {
  const result_id = `${event.target.id}-copy-to-clipboard-result`
  const el = document.getElementById(result_id);

  if ("clipboard" in navigator) {
    if (event.target.tagName === "INPUT") {
      txt = event.target.value;
    } else {
      txt = event.target.textContent;
    }

    navigator.clipboard.writeText(txt).then(() => {
      el.innerText = 'Copied to clipboard';
      // Make it visible
      el.classList.remove('invisible', 'text-red-500', 'opacity-0');
      // Fade in and translate upwards
      el.classList.add('text-green-500', 'opacity-100', '-translate-y-2');

      setTimeout(function () {
        el.classList.remove('text-green-500', 'opacity-100', '-translate-y-2');
        el.classList.add('invisible', 'text-red-500', 'opacity-0');
      }, 2000);

    }).catch(() => {
      el.innerText = 'Could not copy';
      // Make it visible
      el.classList.remove('invisible', 'text-green-500', 'opacity-0');
      // Fade in and translate upwards
      el.classList.add('text-red-500', 'opacity-100', '-translate-y-2');
    })
  } else {
    alert(
      "Sorry, your browser does not support clipboard copy."
    );
  }
});

let socketPath =
  document.querySelector("html").getAttribute("phx-socket") || "/live"
let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content")
let liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
})
liveSocket.connect()
window.liveSocket = liveSocket
