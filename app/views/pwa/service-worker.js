// Bookshelf's service worker: a small script the browser keeps for the
// installed app. It does one thing - when you open a page with no internet
// connection, it shows a friendly "you're offline" page instead of the
// browser's error. Everything else goes straight to the network, so pages
// are never stale.
const CACHE = "bookshelf-offline-v1"
const OFFLINE_PAGE = "/offline.html"

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.add(OFFLINE_PAGE)))
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  // Remove offline pages saved by older versions of this file.
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
  )
  self.clients.claim()
})

self.addEventListener("fetch", (event) => {
  if (event.request.mode !== "navigate") return

  event.respondWith(
    fetch(event.request).catch(() => caches.match(OFFLINE_PAGE))
  )
})
