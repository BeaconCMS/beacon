// https://github.com/phoenixframework/phoenix_live_dashboard/blob/d0f776f4bc2ba119e52ec1e0f9f216962b9b6972/assets/js/app.js

// TODO: connect to custom phx-socket
let socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live"
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {params: {_csrf_token: csrfToken}});

liveSocket.connect()
window.liveSocket = liveSocket
