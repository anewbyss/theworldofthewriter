// Offline cache so WOW Brainstorm works without a connection once installed.
const CACHE = "wow-brainstorm-v1";
const ASSETS = [
  "./", "index.html", "css/styles.css", "manifest.webmanifest", "icon.svg",
  "js/reference-data.js", "js/util.js", "js/store.js", "js/originality.js", "js/continuity.js",
  "js/portrait.js", "js/ink.js", "js/forms.js", "js/views.js", "js/app.js",
];
self.addEventListener("install", (e) => e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS))));
self.addEventListener("activate", (e) => e.waitUntil(
  caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
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
