var Beacon = (() => {
  // js/beacon.js
  var socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live";
  var csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
  window.addEventListener("phx:beacon:page-updated", (e) => {
    document.querySelectorAll("meta:not([name='csrf-token'])").forEach((el) => el.remove());
    e.detail.meta_tags.forEach((metaTag) => {
      let newMetaTag = document.createElement("meta");
      Object.keys(metaTag).forEach((key) => {
        newMetaTag.setAttribute(key, metaTag[key]);
      });
      document.getElementsByTagName("head")[0].appendChild(newMetaTag);
    });
  });
  var liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, { params: { _csrf_token: csrfToken } });
  liveSocket.connect();
  window.liveSocket = liveSocket;
})();
