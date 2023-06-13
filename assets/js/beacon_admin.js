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

window.addEventListener("phx:beacon:clipcopy", (event) => {
  if ("clipboard" in navigator) {
    if (event.target.tagName === "INPUT") {
      navigator.clipboard.writeText(event.target.value)
    } else {
      navigator.clipboard.writeText(event.target.textContent);
    }
  } else {
    alert(
      "Sorry, your browser does not support clipboard copy.\nThis generally requires a secure origin — either HTTPS or localhost."
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
