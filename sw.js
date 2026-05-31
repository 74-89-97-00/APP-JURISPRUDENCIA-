"use strict";

// Troque a versão sempre que atualizar os dados/arquivos para forçar atualização.
const CACHE = "juris-v24";

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
  "icon-512.png",
  "data/stf-vinculantes.js",
  "data/stf-sumulas.js",
  "data/stf-rg.js",
  "data/stf-rg-novos.js",
  "data/stj-sumulas.js",
  "data/stj-rep.js",
  "data/tst-sumulas.js",
  "data/tst-ojs.js",
  "data/tst-pn.js",
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

// O "app" (páginas e código) é pequeno: usamos NETWORK-FIRST para sempre pegar a
// versão nova quando há internet, caindo para o cache quando offline. Os dados
// (data/*.js) são grandes e mudam pouco: CACHE-FIRST para abrir rápido/offline.
function ehAppShell(url) {
  const p = url.pathname;
  if (p.endsWith("/")) return true;
  return /\/(index\.html|sumula\.html|styles\.css|app\.js|sumula\.js)$/.test(p);
}

function guardarNoCache(req, res) {
  if (res && res.status === 200 && res.type === "basic") {
    const copy = res.clone();
    caches.open(CACHE).then((cache) => cache.put(req, copy));
  }
  return res;
}

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);
  const networkFirst = req.mode === "navigate" || ehAppShell(url);

  if (networkFirst) {
    event.respondWith(
      fetch(req)
        .then((res) => guardarNoCache(req, res))
        .catch(() => caches.match(req).then((c) => c || caches.match("index.html")))
    );
  } else {
    // Cache-first (dados, ícone, manifesto).
    event.respondWith(
      caches.match(req).then((cached) => {
        if (cached) return cached;
        return fetch(req).then((res) => guardarNoCache(req, res)).catch(() => cached);
      })
    );
  }
});
