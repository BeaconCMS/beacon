var Beacon = (() => {
  // js/beacon.js
  window.addEventListener("phx:beacon:page-updated", (e) => {
    if (e.detail.hasOwnProperty("runtime_css_path")) {
      document.getElementById("beacon-runtime-stylesheet").href = e.detail.runtime_css_path;
    }
    if (e.detail.hasOwnProperty("meta_tags")) {
      document.querySelectorAll("meta:not([name='csrf-token'])").forEach((el) => el.remove());
      e.detail.meta_tags.forEach((metaTag) => {
        let newMetaTag = document.createElement("meta");
        Object.keys(metaTag).forEach((key) => {
          newMetaTag.setAttribute(key, metaTag[key]);
        });
        document.getElementsByTagName("head")[0].appendChild(newMetaTag);
      });
    }
  });
  var socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live";
  var csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
  var Hooks = {
// BEACON_HOOKS 
  }
  var liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
    params: { _csrf_token: csrfToken },
    hooks: Hooks
  });
  liveSocket.connect();
  window.liveSocket = liveSocket;
})();
