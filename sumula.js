"use strict";

// Página de detalhe de UMA súmula. Recebe ?id=<id> na URL, procura nos dados
// (window.ENTRIES, carregados pelos scripts data/*.js) e monta a página.
const ENTRIES = (window.ENTRIES || []);
const FAV_KEY = "juris.favoritos";
const THEME_KEY = "juris.tema";

const TRIBUNAL_NOME = {
  STF: "Supremo Tribunal Federal",
  STJ: "Superior Tribunal de Justiça",
  TST: "Tribunal Superior do Trabalho",
  TJSP: "Tribunal de Justiça de São Paulo",
  TJRJ: "Tribunal de Justiça do Rio de Janeiro",
};

// ---- Util ----
function norm(s) {
  return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
}
function escapeHtml(s) {
  return (s || "").replace(/[&<>"']/g, c => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
  ));
}

const RE_CONSUMIDOR = /consumidor|consumo|defesa do consumidor|relacao de consumo|\bcdc\b/;
const RE_TRABALHISTA = /trabalhista|empregad|\bclt\b|justica do trabalho|reclamat|sindicat|fgts|salario|aviso previo|hora extra|verbas rescis/;
function materiaDe(e) {
  if (e.tribunal === "TST") return "Trabalhista";
  const tema = norm(e.tema);
  if (tema) {
    if (/consum/.test(tema)) return "Consumidor";
    if (/trabalh/.test(tema)) return "Trabalhista";
    return "Outras";
  }
  const txt = norm(e.texto);
  if (RE_CONSUMIDOR.test(txt)) return "Consumidor";
  if (RE_TRABALHISTA.test(txt)) return "Trabalhista";
  return "Outras";
}

function citaLabel(e) {
  if (e.tipo === "Súmula Vinculante") return `Súmula Vinculante ${e.numero} do ${e.tribunal}`;
  if (e.tipo === "Súmula") return `Súmula ${e.numero} do ${e.tribunal}`;
  if (e.tipo === "Orientação Jurisprudencial") return `Orientação Jurisprudencial nº ${e.numero} do ${e.tribunal}${e.secao ? ` (${e.secao})` : ""}`;
  if (e.tipo === "Precedente Normativo") return `Precedente Normativo nº ${e.numero} do ${e.tribunal}`;
  if (e.tipo === "Repercussão Geral") return `Tema ${e.numero} da Repercussão Geral do ${e.tribunal}`;
  if (e.tipo === "Recurso Repetitivo") return `Tema ${e.numero} dos Recursos Repetitivos do ${e.tribunal}`;
  return `${e.tribunal} ${e.numero}`;
}

// ---- Favoritos ----
function loadFav() {
  try { return new Set(JSON.parse(localStorage.getItem(FAV_KEY)) || []); }
  catch { return new Set(); }
}
function saveFav(set) {
  localStorage.setItem(FAV_KEY, JSON.stringify([...set]));
}

// ---- Copiar ----
function copiar(e, btn) {
  const texto = `${citaLabel(e)}\n\n${e.texto || ""}`.trim();
  const ok = () => { const o = btn.textContent; btn.textContent = "Copiado!"; btn.classList.add("ok"); setTimeout(() => { btn.textContent = o; btn.classList.remove("ok"); }, 1500); };
  const fallback = () => {
    const ta = document.createElement("textarea");
    ta.value = texto; ta.style.position = "fixed"; ta.style.opacity = "0";
    document.body.appendChild(ta); ta.select();
    try { document.execCommand("copy"); ok(); } catch { btn.textContent = "Erro"; }
    document.body.removeChild(ta);
  };
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(texto).then(ok).catch(fallback);
  } else { fallback(); }
}

// ---- Tema ----
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

// ---- Render ----
function getId() {
  const p = new URLSearchParams(location.search);
  return p.get("id") || (location.hash ? decodeURIComponent(location.hash.slice(1)) : "");
}

function tipoExtenso(e) {
  if (e.tipo === "Súmula Vinculante") return "Súmula Vinculante";
  if (e.tipo === "Súmula") return "Súmula";
  if (e.tipo === "Orientação Jurisprudencial") return "Orientação Jurisprudencial";
  if (e.tipo === "Precedente Normativo") return "Precedente Normativo";
  if (e.tipo === "Repercussão Geral") return "Repercussão Geral";
  if (e.tipo === "Recurso Repetitivo") return "Recurso Repetitivo";
  return e.tipo || "—";
}
function tipoCurto(e) {
  if (e.tipo === "Súmula Vinculante") return "Vinculante";
  if (e.tipo === "Súmula") return "Súmula";
  if (e.tipo === "Orientação Jurisprudencial") return "OJ";
  if (e.tipo === "Precedente Normativo") return "PN";
  if (e.tipo === "Repercussão Geral" || e.tipo === "Recurso Repetitivo") return "Tema";
  return e.tipo || "";
}

// Vizinhos (anterior/próxima) dentro do mesmo tribunal, por número.
let vizinhos = { prev: null, next: null };

function renderNav(e) {
  const nav = document.getElementById("sumula-nav");
  const irmas = ENTRIES
    .filter(x => x.tribunal === e.tribunal && x.tipo === e.tipo && (x.secao || "") === (e.secao || ""))
    .sort((a, b) => (parseInt(a.numero, 10) || 0) - (parseInt(b.numero, 10) || 0));
  const idx = irmas.findIndex(x => x.id === e.id);
  const prev = idx > 0 ? irmas[idx - 1] : null;
  const next = idx >= 0 && idx < irmas.length - 1 ? irmas[idx + 1] : null;
  vizinhos = { prev: prev ? prev.id : null, next: next ? next.id : null };

  const btn = (it, dir) => {
    if (!it) return '<span class="nav-btn nav-empty" aria-hidden="true"></span>';
    const rotulo = `${tipoCurto(it)} ${it.numero}`;
    const txt = dir === "prev" ? `‹ ${rotulo}` : `${rotulo} ›`;
    return `<a class="nav-btn nav-${dir}" href="sumula.html?id=${encodeURIComponent(it.id)}">${escapeHtml(txt)}</a>`;
  };
  nav.innerHTML = btn(prev, "prev") + btn(next, "next");
}

function linha(dt, dd) {
  return dd ? `<dt>${dt}</dt><dd>${dd}</dd>` : "";
}

function render() {
  const root = document.getElementById("sumula");
  const e = ENTRIES.find(x => x.id === getId());

  if (!e) {
    root.innerHTML = `<p class="sumula-notfound">Súmula não encontrada. <a href="index.html">Voltar para a lista</a>.</p>`;
    return;
  }

  document.title = citaLabel(e) + " — Jurisprudência";

  const favs = loadFav();
  const fav = favs.has(e.id);
  const cancelada = /cancel/i.test(e.situacao || "");
  const superada = /superad/i.test(e.situacao || "");
  const materia = materiaDe(e);

  root.innerHTML = `
    <div class="sumula-tags">
      <span class="tag tag-tribunal" data-t="${e.tribunal}">${e.tribunal}</span>
      ${materia !== "Outras" ? `<span class="tag tag-materia" data-m="${materia}">${materia}</span>` : ""}
      ${cancelada ? '<span class="tag tag-cancelada">Cancelada</span>' : ""}
      ${superada && !cancelada ? '<span class="tag tag-superada">Superada</span>' : ""}
    </div>
    <h1 class="sumula-num">${escapeHtml(citaLabel(e))}</h1>
    ${e.titulo ? `<p class="sumula-title">${escapeHtml(e.titulo)}</p>` : ""}
    <div class="sumula-text">${escapeHtml(e.texto || "")}</div>
    <dl class="sumula-info">
      ${linha("Tribunal", escapeHtml(TRIBUNAL_NOME[e.tribunal] || e.tribunal))}
      ${linha("Tipo", escapeHtml(tipoExtenso(e)))}
      ${linha("Seção", escapeHtml(e.secao))}
      ${linha("Número", escapeHtml(e.numero))}
      ${linha("Situação", escapeHtml(e.situacao))}
      ${linha("Matéria", escapeHtml(materia))}
      ${linha("Tema", escapeHtml(e.tema))}
      ${linha("Data", escapeHtml(e.data))}
    </dl>
    <div class="sumula-actions">
      <button class="star ${fav ? "on" : ""}" id="fav" type="button" aria-label="Favoritar">${fav ? "★" : "☆"}</button>
      <button class="detail-btn" id="copy" type="button">Copiar citação</button>
      ${e.fonte ? `<a class="detail-btn" href="${escapeHtml(e.fonte)}" target="_blank" rel="noopener">Ver no portal oficial</a>` : ""}
      <button class="detail-btn" id="share" type="button">Compartilhar</button>
    </div>`;

  const favBtn = document.getElementById("fav");
  favBtn.addEventListener("click", () => {
    const set = loadFav();
    if (set.has(e.id)) set.delete(e.id); else set.add(e.id);
    saveFav(set);
    const on = set.has(e.id);
    favBtn.classList.toggle("on", on);
    favBtn.textContent = on ? "★" : "☆";
  });

  document.getElementById("copy").addEventListener("click", (ev) => copiar(e, ev.currentTarget));

  renderNav(e);

  const shareBtn = document.getElementById("share");
  shareBtn.addEventListener("click", async () => {
    const url = location.href;
    const titulo = citaLabel(e);
    try {
      if (navigator.share) { await navigator.share({ title: titulo, url }); return; }
      await navigator.clipboard.writeText(url);
      const o = shareBtn.textContent; shareBtn.textContent = "Link copiado!";
      setTimeout(() => { shareBtn.textContent = o; }, 1500);
    } catch {}
  });
}

// Botão "voltar": usa o histórico se veio do app (preserva filtros/rolagem).
function wireVoltar() {
  const v = document.getElementById("voltar");
  if (!v) return;
  v.addEventListener("click", (ev) => {
    if (history.length > 1 && document.referrer && new URL(document.referrer).origin === location.origin) {
      ev.preventDefault();
      history.back();
    }
  });
}

// Setas ← → navegam entre súmulas (fora de campos de texto).
document.addEventListener("keydown", (ev) => {
  if (/^(INPUT|TEXTAREA|SELECT)$/.test((document.activeElement || {}).tagName || "")) return;
  if (ev.key === "ArrowLeft" && vizinhos.prev) location.href = "sumula.html?id=" + encodeURIComponent(vizinhos.prev);
  if (ev.key === "ArrowRight" && vizinhos.next) location.href = "sumula.html?id=" + encodeURIComponent(vizinhos.next);
});

document.addEventListener("DOMContentLoaded", () => {
  const themeBtn = document.getElementById("theme-toggle");
  if (themeBtn) themeBtn.addEventListener("click", toggleTheme);
  syncThemeBtn();
  wireVoltar();
  render();
});
