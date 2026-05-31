"use strict";

// Troque a versão sempre que atualizar os dados/arquivos para forçar atualização.
const CACHE = "juris-v13";

// Caminhos relativos ao escopo do service worker (funciona em subdiretório no GitHub Pages).
const ASSETS = [
  "./",
  "index.html",
  "sumula.html",
  "styles.css",
  "app.js",
  "sumula.js",
  "manifest.webmanifest",
  "icon.svg",
  "data/stf-vinculantes.js",
  "data/stf-sumulas.js",
  "data/stj-sumulas.js",
  "data/tst-sumulas.js",
  "data/tst-ojs.js",
  "data/tjsp-sumulas.js",
  "data/tjrj-sumulas.js",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  // Cache-first: serve do cache; se faltar, busca na rede e guarda.
  event.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req)
        .then((res) => {
          if (res && res.status === 200 && res.type === "basic") {
            const copy = res.clone();
            caches.open(CACHE).then((cache) => cache.put(req, copy));
          }
          return res;
        })
        .catch(() => cached);
    })
  );
});
