"use strict";

// ---- Estado ----
const ENTRIES = (window.ENTRIES || []).slice();
const FAV_KEY = "juris.favoritos";

const state = {
  query: "",
  tribunais: new Set(),   // vazio = todos
  tipos: new Set(),       // vazio = todos
  onlyFav: false,
  favoritos: new Set(loadFavoritos()),
};

const TRIBUNAIS = ["STF", "STJ", "TST", "TJSP", "TJRJ"];
const TIPOS = [
  { id: "Súmula Vinculante", label: "Vinculante" },
  { id: "Súmula", label: "Súmula" },
  { id: "Julgado", label: "Julgado" },
];

// ---- Util ----
function loadFavoritos() {
  try { return JSON.parse(localStorage.getItem(FAV_KEY)) || []; }
  catch { return []; }
}
function saveFavoritos() {
  localStorage.setItem(FAV_KEY, JSON.stringify([...state.favoritos]));
}
function norm(s) {
  return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
}
function escapeHtml(s) {
  return (s || "").replace(/[&<>"']/g, c => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
  ));
}
function highlight(text, q) {
  const safe = escapeHtml(text);
  if (!q) return safe;
  const nq = norm(q).trim();
  if (!nq) return safe;
  // realça mantendo acentos do original
  const nt = norm(safe);
  let out = "", i = 0;
  while (i < safe.length) {
    const idx = nt.indexOf(nq, i);
    if (idx === -1) { out += safe.slice(i); break; }
    out += safe.slice(i, idx) + "<mark>" + safe.slice(idx, idx + nq.length) + "</mark>";
    i = idx + nq.length;
  }
  return out;
}

// ---- Filtro ----
function matches(e) {
  if (state.onlyFav && !state.favoritos.has(e.id)) return false;
  if (state.tribunais.size && !state.tribunais.has(e.tribunal)) return false;
  if (state.tipos.size && !state.tipos.has(e.tipo)) return false;
  const q = norm(state.query).trim();
  if (q) {
    const hay = norm([e.numero, e.titulo, e.texto, e.tema, e.tribunal].join(" "));
    if (!q.split(/\s+/).every(tok => hay.includes(tok))) return false;
  }
  return true;
}

// ---- Render ----
function render() {
  const list = ENTRIES.filter(matches).sort((a, b) => {
    if (a.tribunal !== b.tribunal) return a.tribunal.localeCompare(b.tribunal);
    return (parseInt(a.numero, 10) || 0) - (parseInt(b.numero, 10) || 0);
  });

  const ul = document.getElementById("results");
  const empty = document.getElementById("empty");
  ul.innerHTML = "";
  empty.hidden = list.length > 0;

  document.getElementById("count").textContent =
    `${list.length} ${list.length === 1 ? "resultado" : "resultados"}` +
    (ENTRIES.length ? ` de ${ENTRIES.length}` : "");

  const q = state.query;
  for (const e of list) {
    const li = document.createElement("li");
    li.className = "card";
    li.dataset.tribunal = e.tribunal;
    const fav = state.favoritos.has(e.id);
    const cancelada = /cancel/i.test(e.situacao || "");
    const superada = /superad/i.test(e.situacao || "");

    li.innerHTML = `
      <div class="card-head">
        <div class="card-tags">
          <span class="tag tag-tribunal" data-t="${e.tribunal}">${e.tribunal}</span>
          <span class="tag tag-num">${escapeHtml(tipoLabel(e.tipo))} ${escapeHtml(e.numero)}</span>
          ${cancelada ? '<span class="tag tag-cancelada">Cancelada</span>' : ""}
          ${superada && !cancelada ? '<span class="tag tag-superada">Superada</span>' : ""}
        </div>
        <button class="star ${fav ? "on" : ""}" title="Favoritar" aria-label="Favoritar">${fav ? "★" : "☆"}</button>
      </div>
      ${e.titulo ? `<p class="card-title">${highlight(e.titulo, q)}</p>` : ""}
      <p class="card-text clamp">${highlight(e.texto, q)}</p>
      <div class="card-foot">
        ${e.tema ? `<span>${escapeHtml(e.tema)}</span>` : ""}
        ${e.data ? `<span>${escapeHtml(e.data)}</span>` : ""}
        <button class="more-btn" type="button">ver mais</button>
        ${e.fonte ? `<a href="${escapeHtml(e.fonte)}" target="_blank" rel="noopener">fonte</a>` : ""}
      </div>`;

    li.querySelector(".star").addEventListener("click", () => toggleFav(e.id));
    const txt = li.querySelector(".card-text");
    const moreBtn = li.querySelector(".more-btn");
    moreBtn.addEventListener("click", () => {
      txt.classList.toggle("clamp");
      moreBtn.textContent = txt.classList.contains("clamp") ? "ver mais" : "ver menos";
    });
    ul.appendChild(li);
  }
}

function tipoLabel(tipo) {
  const t = TIPOS.find(x => x.id === tipo);
  return t ? t.label : (tipo || "");
}

function toggleFav(id) {
  if (state.favoritos.has(id)) state.favoritos.delete(id);
  else state.favoritos.add(id);
  saveFavoritos();
  render();
}

// ---- Chips ----
function buildChips() {
  const tribGroup = document.getElementById("filter-tribunal");
  for (const t of TRIBUNAIS) {
    tribGroup.appendChild(makeChip(t, () => toggleSet(state.tribunais, t)));
  }
  const tipoGroup = document.getElementById("filter-tipo");
  for (const t of TIPOS) {
    tipoGroup.appendChild(makeChip(t.label, () => toggleSet(state.tipos, t.id)));
  }
}
function makeChip(label, onClick) {
  const b = document.createElement("button");
  b.type = "button";
  b.className = "chip";
  b.textContent = label;
  b.addEventListener("click", () => { b.classList.toggle("active"); onClick(); render(); });
  return b;
}
function toggleSet(set, v) { set.has(v) ? set.delete(v) : set.add(v); }

// ---- Init ----
function init() {
  buildChips();

  const search = document.getElementById("search");
  let deb;
  search.addEventListener("input", () => {
    clearTimeout(deb);
    deb = setTimeout(() => { state.query = search.value; render(); }, 120);
  });

  const favBtn = document.getElementById("fav-toggle");
  favBtn.addEventListener("click", () => {
    state.onlyFav = !state.onlyFav;
    favBtn.classList.toggle("active", state.onlyFav);
    favBtn.setAttribute("aria-pressed", String(state.onlyFav));
    render();
  });

  if (window.DATA_UPDATED) {
    document.getElementById("updated").textContent = "Atualizado: " + window.DATA_UPDATED;
  }

  render();
}

document.addEventListener("DOMContentLoaded", init);
