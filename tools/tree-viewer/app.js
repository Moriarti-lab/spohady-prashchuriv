"use strict";
const NS = "http://www.w3.org/2000/svg";
const $ = s => document.querySelector(s);
const stageNames = ["Коріння", "Стовбур", "Крона", "Грона", "Вершина", "Заповнення крони"];
const R = { small: 55, notable: 95, keystone: 125, start: 90, core: 140 };
const TYPE_UA = { start: "старт", small: "малий", notable: "гроно", keystone: "вершина", core: "серце" };
const STAT_NAMES = {
  str: "Сили", agi: "Спритності", faith: "Віри",
  dmg_pct: "шкоди", hp_pct: "життя", armor: "броні", atk_speed_pct: "швидкості атаки",
  hp: "життя", lifesteal_pct: "лічі", thorns_pct: "шипів", block_pct: "блоку",
  dr_pct: "захисту", crit_pct: "крита", dodge_pct: "ухилення", move_pct: "руху",
  proj_speed_pct: "снаряда", crit_dmg_pct: "критичної шкоди", cdr_pct: "відновлення",
  mana_pct: "чару", mana_regen: "відновлення чару", effect_dur_pct: "тривалості",
  hp_regen_pct: "регенерації", res_all_pct: "опору", nauz_xp_pct: "росту наузів",
  skill_cost_pct: "вартості", double_hit_pct: "подвійного удару",
  armor_pen_pct: "пробиття броні", aoe_pct: "площі", pen_all_pct: "пробиття",
  xp_pct: "досвіду"
};

/* ── стан ─────────────────────────────────────────────── */
let T = null, seed = null;
let nodes = [], links = [], byId = new Map(), regColors = {}, adj = new Map();
let stageNodes = [[], [], [], [], [], []], stageLinks = [[], [], [], [], [], []];
let cumBounds = [], fullBounds = null;
let nodeEls = new Map(), linkEls = [];
let revealed = new Set();
let growth = { stage: 0, nodeIdx: 0, linkIdx: 0, pause: 0, carry: 0, done: true, playing: false };
let view = { cx: 0, cy: 0, k: 0.03 }, tv = { ...view };
let KMIN = 0.002, KMAX = 1.5, W = 0, H = 0, follow = true;
let selId = null, busy = false, lastRAF = 0;

const world = $("#world");
const svg = $("#svg");
const stageBox = $("#stage");
const tip = $("#tip");
const PARAMS = new URLSearchParams(location.search);

/* ── утиліти ──────────────────────────────────────────── */
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

function stageOf(n) {
  const id = n.id;
  if (n.type === "start") return 0;
  if (id.startsWith("fruit_") || id.startsWith("fr_")) return 3;
  if (id.startsWith("key_") || id === "core") return 4;
  if (/_tj$/.test(id)) return 2;
  if (/_br$/.test(id)) return 2;
  if (/_tr$/.test(id)) return 1;
  if (/_r$/.test(id)) return 0;
  return 5;
}

function regColor(rg) { return regColors[rg] || "#8a7a62"; }

function speed() {
  const v = Number($("#speed").value);
  return Number.isFinite(v) && v > 0 ? v : 1;
}

function setStageTag(i) {
  const el = $("#stageTag");
  if (i >= 6) el.textContent = `✓ Древо зібрано · ${nodes.length} вузлів`;
  else el.textContent = `${i + 1}/6 · ${stageNames[i]}`;
}

function updatePlay() {
  const b = $("#btnPlay");
  b.textContent = growth.playing ? "⏸ Пауза" : "▶ Далі";
  b.disabled = growth.done;
}

/* ── побудова ─────────────────────────────────────────── */
function buildStages() {
  stageNodes = Array.from({ length: 6 }, () => []);
  stageLinks = Array.from({ length: 6 }, () => []);
  nodes.forEach(n => stageNodes[stageOf(n)].push(n));
  links.forEach(([a, b], i) => {
    const s = Math.max(stageOf(byId.get(a)), stageOf(byId.get(b)));
    stageLinks[s].push(i);
  });
  cumBounds = [];
  let b = null;
  for (let s = 0; s < 6; s++) {
    for (const n of stageNodes[s]) {
      b = b ? { minx: Math.min(b.minx, n.x), miny: Math.min(b.miny, n.y),
                maxx: Math.max(b.maxx, n.x), maxy: Math.max(b.maxy, n.y) }
            : { minx: n.x, miny: n.y, maxx: n.x, maxy: n.y };
    }
    cumBounds[s] = b ? { ...b } : null;
  }
  fullBounds = b ? { ...b } : { minx: -100, miny: -100, maxx: 100, maxy: 100 };
}

function computeLimits() {
  const b = fullBounds;
  const k = Math.min(W / Math.max(1, b.maxx - b.minx), H / Math.max(1, b.maxy - b.miny));
  KMIN = Math.max(0.001, k * 0.45);
  KMAX = 1.5;
}

function buildDom() {
  world.innerHTML = "";
  const lg = document.createElementNS(NS, "g");
  const ng = document.createElementNS(NS, "g");
  lg.id = "linksG"; ng.id = "nodesG";
  world.append(lg, ng);

  linkEls = [];
  links.forEach(([a, b], i) => {
    const A = byId.get(a), B = byId.get(b);
    const l = document.createElementNS(NS, "line");
    l.setAttribute("x1", A.x); l.setAttribute("y1", A.y);
    l.setAttribute("x2", B.x); l.setAttribute("y2", B.y);
    l.setAttribute("class", "link off");
    l.dataset.i = i;
    lg.appendChild(l);
    linkEls.push(l);
  });

  nodeEls.clear();
  nodes.forEach(n => {
    const g = document.createElementNS(NS, "g");
    g.setAttribute("class", "node off");
    g.setAttribute("transform", `translate(${n.x} ${n.y})`);
    g.dataset.id = n.id;
    const pop = document.createElementNS(NS, "g");
    pop.setAttribute("class", "pop");
    const c = document.createElementNS(NS, "circle");
    c.setAttribute("r", R[n.type] || R.small);
    c.setAttribute("fill", regColor(n.region));
    pop.appendChild(c);
    if (n.type !== "small") {
      const h = document.createElementNS(NS, "circle");
      h.setAttribute("r", (R[n.type] || R.small) + 16);
      h.setAttribute("fill", "none");
      h.setAttribute("stroke", n.type === "core" ? "#ffd98a"
        : n.type === "start" ? "#f1e6cf" : "#d9b25b");
      h.setAttribute("stroke-opacity", ".55");
      h.setAttribute("class", "halo");
      pop.appendChild(h);
      const tx = document.createElementNS(NS, "text");
      tx.setAttribute("class", "lbl");
      tx.setAttribute("text-anchor", "middle");
      tx.setAttribute("y", -((R[n.type] || R.small) + 26));
      tx.textContent = n.name;
      pop.appendChild(tx);
    }
    g.appendChild(pop);
    ng.appendChild(g);
    nodeEls.set(n.id, g);
  });
}

function buildLegend() {
  const rc = $("#regChips"); rc.innerHTML = "";
  (T.regions || []).forEach(r => {
    const b = document.createElement("button");
    b.className = "chip on";
    b.dataset.region = r.id;
    b.innerHTML = `<i style="background:${r.color}"></i>${r.name}`;
    b.onclick = () => { b.classList.toggle("on"); refreshFilters(); };
    rc.appendChild(b);
  });
  const tc = $("#typeChips"); tc.innerHTML = "";
  const order = [["start", "старти"], ["small", "малі"], ["notable", "грона"],
                 ["keystone", "вершини"], ["core", "серце"]];
  const cnt = {};
  nodes.forEach(n => { cnt[n.type] = (cnt[n.type] || 0) + 1; });
  order.forEach(([k, label]) => {
    const b = document.createElement("button");
    b.className = "chip on";
    b.dataset.type = k;
    b.innerHTML = `${label} <span style="opacity:.6">${cnt[k] || 0}</span>`;
    b.onclick = () => { b.classList.toggle("on"); refreshFilters(); };
    tc.appendChild(b);
  });
}

function refreshFilters() {
  const regs = new Set([...document.querySelectorAll("#regChips .chip.on")].map(b => b.dataset.region));
  const tys = new Set([...document.querySelectorAll("#typeChips .chip.on")].map(b => b.dataset.type));
  const hidden = new Set();
  nodes.forEach(n => {
    const h = !regs.has(n.region) || !tys.has(n.type);
    nodeEls.get(n.id)?.classList.toggle("hide", h);
    if (h) hidden.add(n.id);
  });
  linkEls.forEach((el, i) => {
    const [a, b] = links[i];
    el.classList.toggle("hide", hidden.has(a) || hidden.has(b));
  });
}

/* ── камера ───────────────────────────────────────────── */
function applyView() {
  world.setAttribute("transform",
    `translate(${W / 2 - view.cx * view.k} ${H / 2 - view.cy * view.k}) scale(${view.k})`);
  svg.classList.toggle("nolabels", view.k < 0.09);
}

function fitTo(b, pad = 0.12) {
  if (!b || !W || !H) return;
  const bw = Math.max(1, (b.maxx - b.minx) * (1 + pad * 2));
  const bh = Math.max(1, (b.maxy - b.miny) * (1 + pad * 2));
  const k = clamp(Math.min(W / bw, H / bh), KMIN, KMAX);
  tv = { cx: (b.minx + b.maxx) / 2, cy: (b.miny + b.maxy) / 2, k };
}

function zoomAt(mx, my, f) {
  const wx = (mx - W / 2) / view.k + view.cx;
  const wy = (my - H / 2) / view.k + view.cy;
  const k = clamp(view.k * f, KMIN, KMAX);
  view.cx = wx - (mx - W / 2) / k;
  view.cy = wy - (my - H / 2) / k;
  view.k = k;
  tv = { ...view };
  applyView();
}

/* ── ріст ─────────────────────────────────────────────── */
function restartGrowth() {
  revealed.clear();
  nodeEls.forEach(el => el.classList.add("off"));
  linkEls.forEach(el => el.classList.add("off"));
  growth = { stage: 0, nodeIdx: 0, linkIdx: 0, pause: 0, carry: 0, done: false, playing: true };
  follow = true;
  setStageTag(0);
  fitTo(cumBounds[0] || fullBounds);
  view = { ...tv };
  applyView();
  updatePlay();
}

function revealAll() {
  revealed.clear();
  nodeEls.forEach(el => el.classList.remove("off"));
  linkEls.forEach(el => el.classList.remove("off"));
  nodes.forEach(n => revealed.add(n.id));
  growth = { stage: 6, nodeIdx: 0, linkIdx: 0, pause: 0, carry: 0, done: true, playing: false };
  follow = false;
  setStageTag(6);
  fitTo(fullBounds);
  view = { ...tv };
  applyView();
  updatePlay();
}

function finishGrowth() {
  growth.playing = false;
  growth.done = true;
  setStageTag(6);
  if (follow) fitTo(fullBounds);
  updatePlay();
}

function animStep() {
  if (!growth.playing || growth.done) return;
  if (growth.pause > 0) { growth.pause--; return; }
  if (growth.stage >= 6) { finishGrowth(); return; }
  const s = growth.stage, N = stageNodes[s], L = stageLinks[s], sp = speed();
  if (growth.nodeIdx < N.length) {
    growth.carry += Math.max(1, N.length / 55) * sp;
    while (growth.carry >= 1 && growth.nodeIdx < N.length) {
      growth.carry -= 1;
      const n = N[growth.nodeIdx++];
      const el = nodeEls.get(n.id);
      if (el) { el.classList.remove("off"); revealed.add(n.id); }
    }
  } else if (growth.linkIdx < L.length) {
    growth.carry += Math.max(1, L.length / 45) * sp;
    while (growth.carry >= 1 && growth.linkIdx < L.length) {
      growth.carry -= 1;
      const el = linkEls[L[growth.linkIdx++]];
      if (el) el.classList.remove("off");
    }
  } else {
    growth.stage++;
    growth.nodeIdx = 0;
    growth.linkIdx = 0;
    if (growth.stage >= 6) { finishGrowth(); return; }
    growth.pause = 8;
    setStageTag(growth.stage);
    if (follow) fitTo(cumBounds[growth.stage]);
  }
}

/* ── виділення / підказки ─────────────────────────────── */
function clearSel() {
  nodeEls.forEach(el => el.classList.remove("sel", "nh"));
  linkEls.forEach(el => el.classList.remove("hl"));
}

function deselect() {
  clearSel();
  selId = null;
  $("#info").hidden = true;
}

function select(id) {
  const n = byId.get(id);
  if (!n) return;
  clearSel();
  selId = id;
  nodeEls.get(id)?.classList.add("sel");
  const nb = adj.get(id) || [];
  nb.forEach(x => nodeEls.get(x)?.classList.add("nh"));
  linkEls.forEach((el, i) => {
    const [a, b] = links[i];
    if ((a === id || b === id) && !el.classList.contains("off") && !el.classList.contains("hide")) {
      el.classList.add("hl");
    }
  });

  $("#iName").textContent = n.name;
  $("#iChips").innerHTML =
    `<span class="pill">${TYPE_UA[n.type] || n.type}</span>` +
    `<span class="pill"><i style="background:${regColor(n.region)}"></i>` +
    `${((T.regions || []).find(r => r.id === n.region) || {}).name || n.region}</span>`;
  $("#iDesc").textContent = n.description || "";
  const st = Object.entries(n.stats || {}).map(([k, v]) => {
    const pct = !["str", "agi", "faith"].includes(k);
    const val = (v > 0 ? "+" : "−") + Math.abs(v) + (pct ? "%" : "");
    return `<span class="${v < 0 ? "neg" : ""}">${STAT_NAMES[k] || k} <b>${val}</b></span>`;
  }).join("");
  $("#iStats").innerHTML = st || '<span style="opacity:.6">без бонусів</span>';
  $("#iLinks").textContent = `зв'язків: ${nb.length}`;
  $("#info").hidden = false;
}

function showTip(id, cx, cy) {
  const n = byId.get(id);
  if (!n) return;
  tip.innerHTML = `<b>${n.name}</b> <span class="dim">· ${TYPE_UA[n.type] || n.type}</span><br>` +
    `<span class="dim">${n.description || ""}</span>`;
  tip.style.left = clamp(cx + 16, 8, innerWidth - 360) + "px";
  tip.style.top = clamp(cy + 16, 8, innerHeight - 130) + "px";
  tip.classList.add("show");
}

function hideTip() { tip.classList.remove("show"); }

/* ── статистика ───────────────────────────────────────── */
function computeStats() {
  const seen = new Set();
  const starts = Object.values(T.class_starts || {}).filter(s => byId.has(s));
  const q = [...starts];
  while (q.length) {
    const c = q.pop();
    if (seen.has(c)) continue;
    seen.add(c);
    for (const nb of adj.get(c) || []) if (!seen.has(nb)) q.push(nb);
  }
  let md = Infinity;
  for (let i = 0; i < nodes.length; i++) {
    for (let j = i + 1; j < nodes.length; j++) {
      const a = nodes[i], b = nodes[j];
      const d = Math.hypot(a.x - b.x, a.y - b.y);
      if (d < md) md = d;
    }
  }
  return {
    nodes: nodes.length, links: links.length,
    reachable: seen.size, orphans: nodes.length - seen.size,
    min_dist: Number.isFinite(md) ? md : 0
  };
}

function setFoot(s) {
  $("#fNodes").textContent = s.nodes;
  $("#fLinks").textContent = s.links;
  $("#fReach").textContent = s.reachable;
  const o = $("#fOrph");
  o.textContent = s.orphans;
  o.classList.toggle("bad", s.orphans > 0);
  $("#fDeg").textContent = (2 * s.links / Math.max(1, s.nodes)).toFixed(2);
  $("#fDist").textContent = Math.round(s.min_dist);
  $("#fSeed").textContent = seed ?? "—";
}

/* ── ініціалізація дерева ─────────────────────────────── */
function init(tree, meta = {}) {
  T = tree;
  seed = meta.seed ?? null;
  nodes = tree.nodes || [];
  links = tree.links || [];
  byId = new Map(nodes.map(n => [n.id, n]));
  regColors = {};
  (tree.regions || []).forEach(r => { regColors[r.id] = r.color; });
  adj = new Map();
  nodes.forEach(n => adj.set(n.id, []));
  links.forEach(([a, b]) => {
    if (adj.has(a) && adj.has(b)) { adj.get(a).push(b); adj.get(b).push(a); }
  });
  selId = null;
  $("#info").hidden = true;
  hideTip();

  buildStages();
  computeLimits();
  buildDom();
  buildLegend();
  refreshFilters();
  $("#seedIn").value = seed ?? "";
  $("#log").textContent = meta.log || "—";
  setFoot(computeStats());
  $("#fStatus").textContent = meta.source === "file"
    ? "з файлу"
    : (meta.duration ? `згенеровано за ${meta.duration} с` : "готово");
  if (PARAMS.has("instant") && PARAMS.get("instant") !== "0") revealAll();
  else restartGrowth();
}

/* ── генерація ────────────────────────────────────────── */
async function regenerate(seedArg) {
  if (busy) return;
  busy = true;
  $("#btnGen").disabled = true;
  $("#fStatus").textContent = "генерую…";
  $("#stageTag").textContent = "⚙ генерація…";
  try {
    const body = seedArg === undefined ? {} : { seed: seedArg };
    const r = await fetch("/api/generate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });
    const d = await r.json();
    if (!r.ok) throw new Error(d.error || ("HTTP " + r.status));
    init(d.tree, { seed: d.seed, log: d.log, duration: d.duration });
  } catch (e) {
    $("#fStatus").textContent = "помилка генерації";
    $("#stageTag").textContent = "⚠ " + String(e.message || e).slice(0, 140);
    console.error(e);
  } finally {
    busy = false;
    $("#btnGen").disabled = false;
  }
}

async function boot() {
  try {
    const r = await fetch("/api/tree", { cache: "no-store" });
    if (r.ok) {
      const d = await r.json();
      init(d.tree, { seed: d.seed, log: d.log, duration: d.duration });
      return;
    }
    if (r.status === 404) { await regenerate(); return; }
    throw new Error("HTTP " + r.status);
  } catch (e) {
    $("#stageTag").textContent = "⤒ відкрий perk_tree.json (без сервера)";
    $("#fStatus").textContent = "офлайн";
    console.warn(e);
  }
}

/* ── керування ────────────────────────────────────────── */
$("#btnGen").onclick = () => regenerate();
$("#btnSeed").onclick = () => {
  const v = $("#seedIn").value.trim();
  const n = /^0x/i.test(v) ? parseInt(v, 16) : parseInt(v, 10);
  if (Number.isFinite(n)) regenerate(n); else regenerate();
};
$("#btnPlay").onclick = () => {
  if (growth.done) { restartGrowth(); return; }
  growth.playing = !growth.playing;
  updatePlay();
};
$("#btnReplay").onclick = () => restartGrowth();
$("#btnAll").onclick = () => { follow = false; fitTo(fullBounds); };
$("#btnDl").onclick = () => {
  if (!T) return;
  const blob = new Blob([JSON.stringify(T, null, 2)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `perk_tree_${seed ?? "view"}.json`;
  a.click();
  URL.revokeObjectURL(a.href);
};
$("#btnLoad").onclick = () => $("#fileIn").click();
$("#fileIn").onchange = e => {
  const f = e.target.files[0];
  if (!f) return;
  const rd = new FileReader();
  rd.onload = () => {
    try {
      init(JSON.parse(rd.result), { source: "file" });
      $("#fStatus").textContent = `з файлу: ${f.name}`;
    } catch (err) {
      $("#stageTag").textContent = "⚠ некоректний JSON";
      console.error(err);
    }
  };
  rd.readAsText(f);
  e.target.value = "";
};
$("#btnLog").onclick = () => $("#log").classList.toggle("open");
$("#infoX").onclick = deselect;

function setLegend(closed) {
  $("#legend").classList.toggle("closed", closed);
  const b = $("#lgBtn");
  b.textContent = closed ? "＋" : "−";
  b.title = closed ? "Розгорнути легенду" : "Згорнути легенду";
}
$("#lgBtn").onclick = () => setLegend(!$("#legend").classList.contains("closed"));

window.addEventListener("keydown", e => {
  if (e.target.matches("input,select,textarea")) return;
  if (e.code === "Space") { e.preventDefault(); $("#btnPlay").click(); }
  else if (e.key === "f" || e.key === "F") $("#btnAll").click();
  else if (e.key === "r" || e.key === "R") $("#btnReplay").click();
  else if (e.key === "g" || e.key === "G") $("#btnGen").click();
  else if (e.key === "Escape") deselect();
});

window.addEventListener("resize", () => {
  resize();
  if (follow) fitTo(growth.done ? fullBounds : (cumBounds[Math.min(growth.stage, 5)] || fullBounds));
});

/* ── миша / тач ───────────────────────────────────────── */
let ptrs = new Map(), dragStart = null, pinchD = null, moved = 0;

function dist2(m) {
  const [a, b] = [...m.values()];
  return Math.hypot(a.x - b.x, a.y - b.y);
}
function mid2(m) {
  const [a, b] = [...m.values()];
  return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
}

svg.addEventListener("pointerdown", e => {
  svg.setPointerCapture(e.pointerId);
  ptrs.set(e.pointerId, { x: e.clientX, y: e.clientY });
  moved = 0;
  if (ptrs.size === 1) {
    dragStart = { x: e.clientX, y: e.clientY };
    svg.classList.add("drag");
    follow = false;
  } else if (ptrs.size === 2) {
    pinchD = dist2(ptrs);
    pinchMid = mid2(ptrs);
  }
});

let pinchMid = null;
svg.addEventListener("pointermove", e => {
  if (!ptrs.has(e.pointerId)) return;
  const prev = ptrs.get(e.pointerId);
  ptrs.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (ptrs.size === 1 && dragStart) {
    const dx = e.clientX - prev.x, dy = e.clientY - prev.y;
    moved += Math.abs(dx) + Math.abs(dy);
    view.cx -= dx / view.k;
    view.cy -= dy / view.k;
    tv = { ...view };
    applyView();
  } else if (ptrs.size === 2 && pinchD !== null) {
    const d = dist2(ptrs);
    if (d > 0 && pinchD > 0) {
      const r = stageBox.getBoundingClientRect();
      const m = mid2(ptrs);
      zoomAt(m.x - r.left, m.y - r.top, d / pinchD);
      follow = false;
    }
    pinchD = d;
    moved += 4;
  }
});

function endPtr(e) {
  ptrs.delete(e.pointerId);
  if (ptrs.size < 2) pinchD = null;
  if (ptrs.size === 0) {
    dragStart = null;
    svg.classList.remove("drag");
  }
}
svg.addEventListener("pointerup", endPtr);
svg.addEventListener("pointercancel", endPtr);

svg.addEventListener("wheel", e => {
  e.preventDefault();
  const r = stageBox.getBoundingClientRect();
  zoomAt(e.clientX - r.left, e.clientY - r.top, Math.pow(1.0015, -e.deltaY));
  follow = false;
}, { passive: false });

svg.addEventListener("mousemove", e => {
  if (ptrs.size) { hideTip(); return; }
  const g = e.target.closest ? e.target.closest("g.node") : null;
  if (g) showTip(g.dataset.id, e.clientX, e.clientY);
  else hideTip();
});

svg.addEventListener("click", e => {
  if (moved > 6) { moved = 0; return; }
  const g = e.target.closest ? e.target.closest("g.node") : null;
  if (g) select(g.dataset.id); else deselect();
});

/* ── цикл ─────────────────────────────────────────────── */
function resize() {
  W = stageBox.clientWidth || innerWidth;
  H = stageBox.clientHeight || innerHeight;
  applyView();
}

let lastTS = 0;
function loop(ts) {
  animStep();
  const dx = tv.cx - view.cx, dy = tv.cy - view.cy, dk = tv.k - view.k;
  if (Math.abs(dx) > 1e-9 || Math.abs(dy) > 1e-9 || Math.abs(dk) > 1e-9) {
    view.cx += dx * 0.16;
    view.cy += dy * 0.16;
    view.k += dk * 0.16;
    const eps = 1 / Math.max(view.k, 1e-6);
    if (Math.abs(tv.cx - view.cx) < eps && Math.abs(tv.cy - view.cy) < eps &&
        Math.abs(tv.k - view.k) / Math.max(tv.k, 1e-9) < 0.002) {
      view = { ...tv };
    }
    applyView();
  }
  lastTS = ts;
  lastRAF = ts;
  requestAnimationFrame(loop);
}

resize();
setLegend(innerWidth < 760);
updatePlay();
requestAnimationFrame(loop);
setInterval(() => { if (performance.now() - lastRAF > 300) animStep(); }, 120);
boot();
