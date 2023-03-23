// app.js used by Admin and Sites (runtime)
//
// Note:
// 1. run `mix assets.build` to distribute updated static assets
// 2. phoenix js loaded from the host application

let socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live"
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

window.addEventListener("phx:beacon:page-updated", e => {
  if (e.detail.hasOwnProperty('runtime_css_path')) {
    document.getElementById('beacon-runtime-stylesheet').href = e.detail.runtime_css_path
  }

  if (e.detail.hasOwnProperty('meta_tags')) {
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
  }
})

let liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {params: {_csrf_token: csrfToken}})
liveSocket.connect()
window.liveSocket = liveSocket
