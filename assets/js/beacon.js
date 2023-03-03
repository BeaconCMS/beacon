// app.js used by Admin and Sites (runtime)
//
// run `mix assets.build` to distribute updated static assets

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live"
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

window.addEventListener("phx:beacon:page-updated", e => {
  // remove current tags, except csrf-token
  document.querySelectorAll("meta:not([name='csrf-token'])").forEach(el => el.remove())

  // create the new meta tags
  e.detail.meta_tags.forEach((metaTag) => {
    let newMetaTag = document.createElement("meta")

    Object.keys(metaTag).forEach((key) => {
      newMetaTag.setAttribute(key, metaTag[key])
    })

    document.getElementsByTagName('head')[0].appendChild(newMetaTag);
  })
})

let liveSocket = new LiveSocket(socketPath, Socket, {params: {_csrf_token: csrfToken}})
liveSocket.connect()
window.liveSocket = liveSocket
