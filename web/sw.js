// Offline cache so WOW Brainstorm works without a connection once installed.
const CACHE = "wow-brainstorm-v16";
const ASSETS = [
  "./", "index.html", "css/styles.css", "manifest.webmanifest", "icon.svg",
  "js/reference-data.js", "js/util.js", "js/store.js", "js/refdata.js", "js/originality.js", "js/continuity.js",
  "js/portrait.js", "js/maps.js", "js/ink.js", "js/forms.js", "js/views.js", "js/worldviews.js", "js/heirlooms.js", "js/kin.js", "js/conflicts.js", "js/beings.js", "js/lore.js", "js/timeatlas.js", "js/lands.js", "js/economy-data.js", "js/economy.js", "js/write.js", "js/geo-data.js", "js/heredity.js", "js/app.js",
];
// Take over straight away, so the very first visit is already ready to work offline.
self.addEventListener("install", (e) => e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting())));
self.addEventListener("activate", (e) => e.waitUntil(
  caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim())
));
// Network first, so updates arrive when online; cache when offline.
self.addEventListener("fetch", (e) => {
  if (e.request.method !== "GET") return;
  e.respondWith(
    fetch(e.request).then((res) => {
      const copy = res.clone();
      caches.open(CACHE).then((c) => c.put(e.request, copy));
      return res;
    }).catch(() => caches.match(e.request))
  );
});
