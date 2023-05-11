// Beacon Admin
//
// Note:
// 1. run `mix assets.build` to distribute updated static assets
// 2. phoenix js loaded from the host application

import { CodeEditorHook } from "../../deps/live_monaco_editor/priv/static/main.js"

let Hooks = {}
Hooks.CodeEditorHook = CodeEditorHook

let socketPath = document.querySelector('html').getAttribute('phx-socket') || '/live'
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute('content')
let liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
})
liveSocket.connect()
window.liveSocket = liveSocket
