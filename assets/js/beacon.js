// Beacon runtime (sites)
//
// Note:
// 1. run `mix assets.build` to distribute updated static assets
// 2. phoenix js loaded from the host application

window.addEventListener("phx:beacon:css-ready", (e) => {
  let link = document.querySelector("#beacon-runtime-stylesheet")
  if (link) {
    link.href = e.detail.href
  }
})

window.addEventListener("phx:beacon:page-updated", (e) => {
  if (Object.prototype.hasOwnProperty.call(e.detail, "runtime_css_path")) {
    document.querySelector("#beacon-runtime-stylesheet").href = e.detail.runtime_css_path
  }

  if (Object.prototype.hasOwnProperty.call(e.detail, "meta_tags")) {
    // remove current tags, except csrf-token
    document.querySelectorAll("meta:not([name='csrf-token'])").forEach((el) => el.remove())

    // create the new meta tags
    e.detail.meta_tags.forEach((metaTag) => {
      let newMetaTag = document.createElement("meta")

      Object.keys(metaTag).forEach((key) => {
        newMetaTag.setAttribute(key, metaTag[key])
      })

      document.head.append(newMetaTag)
    })
  }
})

let socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live"
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let beaconHooks = window.BeaconHooks?.default ?? {}
let liveSocket = window.liveSocket

if (liveSocket) {
  Object.assign(liveSocket.hooks || (liveSocket.hooks = {}), beaconHooks)
} else {
  liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
    params: { _csrf_token: csrfToken },
    hooks: beaconHooks,
  })
  liveSocket.connect()
  window.liveSocket = liveSocket
}
