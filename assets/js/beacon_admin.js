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

  editor.onDidBlurEditorWidget(() => {
    hook.pushEvent("code-editor-lost-focus", { value: editor.getValue() })
  })
})

let socketPath = document.querySelector('html').getAttribute('phx-socket') || '/live'
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute('content')
let liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
})
liveSocket.connect()
window.liveSocket = liveSocket
