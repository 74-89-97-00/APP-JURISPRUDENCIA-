"use strict";

// ---- Estado ----
const ENTRIES = (window.ENTRIES || []).slice();
const FAV_KEY = "juris.favoritos";

const state = {
  query: "",
  tribunais: new Set(),   // vazio = todos
  tipos: new Set(),       // vazio = todos
  materias: new Set(),    // vazio = todas
  onlyFav: false,
  sort: "tribunal",       // tribunal | numero | fav
  favoritos: new Set(loadFavoritos()),
};

const TRIBUNAIS = ["STF", "STJ", "TST", "TJSP", "TJRJ"];
const TIPOS = [
  { id: "Súmula Vinculante", label: "Vinculante" },
  { id: "Súmula", label: "Súmula" },
  { id: "Julgado", label: "Julgado" },
];
const MATERIAS = ["Consumidor", "Trabalhista", "Outras"];

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

// ---- Classificação por matéria ----
// Só três grupos: Consumidor, Trabalhista, Outras. As palavras-chave abaixo são
// lógica interna (não viram chips). Regra: TST é sempre trabalhista; quando há
// `tema` curado (caso do STJ) ele manda; senão, heurística por texto.
const RE_CONSUMIDOR = /consumidor|consumo|defesa do consumidor|relacao de consumo|\bcdc\b/;
const RE_TRABALHISTA = /trabalhista|empregad|\bclt\b|justica do trabalho|reclamat|sindicat|fgts|salario|aviso previo|hora extra|verbas rescis/;

function materiaDe(e) {
  if (e.tribunal === "TST") return "Trabalhista";
  const tema = norm(e.tema);
  if (tema) {
    if (/consum/.test(tema)) return "Consumidor";
    if (/trabalh/.test(tema)) return "Trabalhista";
    return "Outras"; // tema curado e não é nenhuma das duas
  }
  const txt = norm(e.texto);
  if (RE_CONSUMIDOR.test(txt)) return "Consumidor";
  if (RE_TRABALHISTA.test(txt)) return "Trabalhista";
  return "Outras";
}

// ---- Filtro ----
function matches(e) {
  if (state.onlyFav && !state.favoritos.has(e.id)) return false;
  if (state.tribunais.size && !state.tribunais.has(e.tribunal)) return false;
  if (state.tipos.size && !state.tipos.has(e.tipo)) return false;
  if (state.materias.size && !state.materias.has(materiaDe(e))) return false;
  const q = norm(state.query).trim();
  if (q) {
    const hay = norm([e.numero, e.titulo, e.texto, e.tema, e.tribunal].join(" "));
    if (!q.split(/\s+/).every(tok => hay.includes(tok))) return false;
  }
  return true;
}

// ---- Ordenação ----
function porTribunalNumero(a, b) {
  if (a.tribunal !== b.tribunal) return a.tribunal.localeCompare(b.tribunal);
  return (parseInt(a.numero, 10) || 0) - (parseInt(b.numero, 10) || 0);
}
function sortFn(a, b) {
  if (state.sort === "fav") {
    const fa = state.favoritos.has(a.id), fb = state.favoritos.has(b.id);
    if (fa !== fb) return fa ? -1 : 1;
    return porTribunalNumero(a, b);
  }
  if (state.sort === "numero") {
    const na = parseInt(a.numero, 10) || 0, nb = parseInt(b.numero, 10) || 0;
    if (na !== nb) return na - nb;
    return a.tribunal.localeCompare(b.tribunal);
  }
  return porTribunalNumero(a, b);
}

function anyFilterActive() {
  return state.tribunais.size || state.tipos.size || state.materias.size ||
    state.onlyFav || state.query.trim();
}

function citaLabel(e) {
  if (e.tipo === "Súmula Vinculante") return `Súmula Vinculante ${e.numero} do ${e.tribunal}`;
  if (e.tipo === "Súmula") return `Súmula ${e.numero} do ${e.tribunal}`;
  return `${e.tribunal} ${e.numero}`;
}

// ---- Render (paginado: mantém a rolagem/cliques fluidos com milhares de itens) ----
const CHUNK = 60;
let currentList = [];
let renderedCount = 0;

function applyFilters(opts) {
  currentList = ENTRIES.filter(matches).sort(sortFn);
  renderedCount = 0;
  const ul = document.getElementById("results");
  ul.innerHTML = "";
  document.getElementById("empty").hidden = currentList.length > 0;

  const clearBtn = document.getElementById("clear-filters");
  if (clearBtn) clearBtn.hidden = !anyFilterActive();
  updateFiltersBadge();

  const n = currentList.length;
  document.getElementById("count").textContent =
    `${n} ${n === 1 ? "resultado" : "resultados"}` +
    (ENTRIES.length ? ` de ${ENTRIES.length}` : "");

  appendChunk();
  if (!opts || opts.scroll !== false) window.scrollTo({ top: 0 });
}

function appendChunk() {
  const ul = document.getElementById("results");
  const frag = document.createDocumentFragment();
  const next = currentList.slice(renderedCount, renderedCount + CHUNK);
  for (const e of next) frag.appendChild(buildCard(e));
  ul.appendChild(frag);
  renderedCount += next.length;
  updateLoadMore();
}

function updateLoadMore() {
  const btn = document.getElementById("load-more");
  if (!btn) return;
  const restantes = currentList.length - renderedCount;
  btn.hidden = restantes <= 0;
  if (restantes > 0) btn.textContent = `Carregar mais (${restantes})`;
}

function updateFiltersBadge() {
  const t = document.getElementById("filters-toggle");
  if (!t) return;
  const n = state.tribunais.size + state.tipos.size + state.materias.size + (state.onlyFav ? 1 : 0);
  t.firstChild ? (t.firstChild.nodeValue = n ? `Filtros (${n})` : "Filtros")
               : (t.textContent = n ? `Filtros (${n})` : "Filtros");
}

function buildCard(e) {
  const q = state.query;
  const li = document.createElement("li");
  li.className = "card";
  li.dataset.tribunal = e.tribunal;
  li.dataset.id = e.id;
  const fav = state.favoritos.has(e.id);
  const cancelada = /cancel/i.test(e.situacao || "");
  const superada = /superad/i.test(e.situacao || "");
  const materia = materiaDe(e);

  li.innerHTML = `
    <div class="card-head">
      <div class="card-id">
        <span class="tag tag-tribunal" data-t="${e.tribunal}">${e.tribunal}</span>
        <span class="card-num">${escapeHtml(tipoLabel(e.tipo))} ${escapeHtml(e.numero)}</span>
        <span class="tag tag-materia" data-m="${materia}">${materia}</span>
        ${cancelada ? '<span class="tag tag-cancelada">Cancelada</span>' : ""}
        ${superada && !cancelada ? '<span class="tag tag-superada">Superada</span>' : ""}
      </div>
      <button class="star ${fav ? "on" : ""}" title="Favoritar" aria-label="Favoritar">${fav ? "★" : "☆"}</button>
    </div>
    ${e.titulo ? `<p class="card-title">${highlight(e.titulo, q)}</p>` : ""}
    <p class="card-text clamp">${highlight(e.texto, q)}</p>
    <div class="card-foot">
      ${e.tema ? `<span class="foot-tema">${escapeHtml(e.tema)}</span>` : ""}
      ${e.data ? `<span>${escapeHtml(e.data)}</span>` : ""}
      <span class="abrir-hint">abrir ›</span>
      <button class="copy-btn" type="button" title="Copiar citação e texto">copiar</button>
      ${e.fonte ? `<a href="${escapeHtml(e.fonte)}" target="_blank" rel="noopener">fonte</a>` : ""}
    </div>`;

  li.querySelector(".star").addEventListener("click", (ev) => { ev.stopPropagation(); toggleFav(e); });
  li.querySelector(".copy-btn").addEventListener("click", (ev) => { ev.stopPropagation(); copiar(e, ev.currentTarget); });
  // Clicar em qualquer lugar do card (menos botões/links) abre a página da súmula.
  li.addEventListener("click", (ev) => {
    if (ev.target.closest("button, a")) return;
    location.href = "sumula.html?id=" + encodeURIComponent(e.id);
  });
  return li;
}

function tipoLabel(tipo) {
  const t = TIPOS.find(x => x.id === tipo);
  return t ? t.label : (tipo || "");
}

function toggleFav(e) {
  const id = e.id;
  if (state.favoritos.has(id)) state.favoritos.delete(id);
  else state.favoritos.add(id);
  saveFavoritos();
  const on = state.favoritos.has(id);
  const sel = (typeof CSS !== "undefined" && CSS.escape) ? CSS.escape(id) : id;
  const li = document.querySelector(`.card[data-id="${sel}"]`);
  if (li) {
    const s = li.querySelector(".star");
    s.classList.toggle("on", on);
    s.textContent = on ? "★" : "☆";
  }
  // Só re-filtra quando a mudança afeta o que aparece/ordem.
  if (state.onlyFav || state.sort === "fav") applyFilters({ scroll: false });
}

// ---- Copiar citação ----
function copiar(e, btn) {
  const texto = `${citaLabel(e)}\n\n${e.texto || ""}`.trim();
  const feedback = (msg, cls) => {
    const old = btn.textContent;
    btn.textContent = msg;
    btn.classList.add(cls);
    setTimeout(() => { btn.textContent = old; btn.classList.remove(cls); }, 1500);
  };
  const fallback = () => {
    const ta = document.createElement("textarea");
    ta.value = texto;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); feedback("copiado!", "ok"); }
    catch { feedback("erro", "err"); }
    document.body.removeChild(ta);
  };
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(texto).then(() => feedback("copiado!", "ok")).catch(fallback);
  } else {
    fallback();
  }
}

// ---- Tema ----
const THEME_KEY = "juris.tema";
function currentTheme() {
  return document.documentElement.getAttribute("data-theme") === "light" ? "light" : "dark";
}
function syncThemeBtn() {
  const btn = document.getElementById("theme-toggle");
  if (!btn) return;
  const light = currentTheme() === "light";
  btn.textContent = light ? "☾" : "☀";
  btn.setAttribute("aria-label", light ? "Ativar tema escuro" : "Ativar tema claro");
}
function toggleTheme() {
  const next = currentTheme() === "light" ? "dark" : "light";
  document.documentElement.setAttribute("data-theme", next);
  try { localStorage.setItem(THEME_KEY, next); } catch {}
  syncThemeBtn();
}

function clearFilters() {
  state.tribunais.clear();
  state.tipos.clear();
  state.materias.clear();
  state.onlyFav = false;
  state.query = "";
  const search = document.getElementById("search");
  if (search) search.value = "";
  document.querySelectorAll(".chip.active").forEach(c => c.classList.remove("active"));
  const favBtn = document.getElementById("fav-toggle");
  if (favBtn) { favBtn.classList.remove("active"); favBtn.setAttribute("aria-pressed", "false"); }
  const sc = document.getElementById("search-clear");
  if (sc) sc.hidden = true;
  applyFilters();
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
  const materiaGroup = document.getElementById("filter-materia");
  for (const m of MATERIAS) {
    materiaGroup.appendChild(makeChip(m, () => toggleSet(state.materias, m)));
  }
}
function makeChip(label, onClick) {
  const b = document.createElement("button");
  b.type = "button";
  b.className = "chip";
  b.textContent = label;
  b.addEventListener("click", () => { b.classList.toggle("active"); onClick(); applyFilters(); });
  return b;
}
function toggleSet(set, v) { set.has(v) ? set.delete(v) : set.add(v); }

// ---- Init ----
function init() {
  buildChips();

  const search = document.getElementById("search");
  const clearSearch = document.getElementById("search-clear");
  const syncClearSearch = () => { if (clearSearch) clearSearch.hidden = !search.value; };
  let deb;
  search.addEventListener("input", () => {
    syncClearSearch();
    clearTimeout(deb);
    deb = setTimeout(() => { state.query = search.value; applyFilters(); }, 120);
  });
  search.addEventListener("keydown", (ev) => {
    if (ev.key === "Escape" && search.value) {
      search.value = ""; state.query = ""; syncClearSearch(); applyFilters();
    }
  });
  if (clearSearch) clearSearch.addEventListener("click", () => {
    search.value = ""; state.query = ""; syncClearSearch(); applyFilters(); search.focus();
  });
  // Atalho de teclado: "/" foca a busca.
  document.addEventListener("keydown", (ev) => {
    if (ev.key === "/" &&
        !/^(INPUT|TEXTAREA|SELECT)$/.test((document.activeElement || {}).tagName || "")) {
      ev.preventDefault(); search.focus();
    }
  });

  const favBtn = document.getElementById("fav-toggle");
  favBtn.addEventListener("click", () => {
    state.onlyFav = !state.onlyFav;
    favBtn.classList.toggle("active", state.onlyFav);
    favBtn.setAttribute("aria-pressed", String(state.onlyFav));
    applyFilters();
  });

  const clearBtn = document.getElementById("clear-filters");
  if (clearBtn) clearBtn.addEventListener("click", clearFilters);

  const sortSel = document.getElementById("sort");
  if (sortSel) sortSel.addEventListener("change", () => { state.sort = sortSel.value; applyFilters(); });

  const themeBtn = document.getElementById("theme-toggle");
  if (themeBtn) themeBtn.addEventListener("click", toggleTheme);
  syncThemeBtn();

  const filtersToggle = document.getElementById("filters-toggle");
  const filtersNav = document.getElementById("filters");
  if (filtersToggle && filtersNav) {
    filtersToggle.addEventListener("click", () => {
      const open = filtersNav.classList.toggle("open");
      filtersToggle.setAttribute("aria-expanded", String(open));
    });
  }

  // Carregar mais: botão manual + auto-carregamento ao rolar (scroll infinito).
  const loadMore = document.getElementById("load-more");
  if (loadMore) {
    loadMore.addEventListener("click", appendChunk);
    if ("IntersectionObserver" in window) {
      const io = new IntersectionObserver((entries) => {
        if (entries.some(en => en.isIntersecting) && renderedCount < currentList.length) {
          appendChunk();
        }
      }, { rootMargin: "800px" });
      io.observe(loadMore);
    }
  }

  // Voltar ao topo.
  const toTop = document.getElementById("to-top");
  if (toTop) {
    toTop.addEventListener("click", () => window.scrollTo({ top: 0, behavior: "smooth" }));
    window.addEventListener("scroll", () => { toTop.hidden = window.scrollY < 600; }, { passive: true });
  }

  if (window.DATA_UPDATED) {
    document.getElementById("updated").textContent = "Atualizado: " + window.DATA_UPDATED;
  }

  applyFilters({ scroll: false });
}

document.addEventListener("DOMContentLoaded", init);
