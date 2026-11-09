/*
 * Тести моделі редактора розкладки UI.
 * Блок моделі вирізається з index.html між маркерами й виконується в node,
 * тому модель не має права чіпати DOM, window чи localStorage.
 *
 * Запуск: node tools/ui-layout-editor/test_model.js
 */
const fs = require("fs");
const path = require("path");
const assert = require("assert");

const HTML = fs.readFileSync(path.join(__dirname, "index.html"), "utf8");
const block = (HTML.match(/\/\/ === MODEL START ===([\s\S]*?)\/\/ === MODEL END ===/) || [])[1];
const mod = { exports: {} };
new Function("module", block)(mod);
const M = mod.exports;

let fails = 0;
function t(name, fn) {
  try {
    fn();
    console.log("  ok   " + name);
  } catch (e) {
    fails++;
    console.log("  FAIL " + name + ": " + e.message);
  }
}

// ---------------------------------------------------------------- Task 1

t("полотно за замовчуванням — 1560×720", () => {
  assert.deepEqual(M.defaultCanvas(), { w: 1560, h: 720 });
});

t("п'ять пресетів, перший 19.5:9", () => {
  assert.equal(M.PRESETS.length, 5);
  assert.deepEqual(M.PRESETS[0], { id: "19.5:9", w: 1560, h: 720, physical: "1024×473" });
  assert.deepEqual(M.PRESETS.map((p) => p.id), ["19.5:9", "16:9", "18:9", "20:9", "21:9"]);
});

t("розмітка має полотно, палітру, інспектор і панель перевірок", () => {
  for (const id of ["canvas", "palette", "inspector", "issues", "topbar"]) {
    assert.ok(HTML.includes('id="' + id + '"'), "немає #" + id);
  }
});


// ---------------------------------------------------------------- Task 2

t("шаблон: п'ять екранів у сталому порядку", () => {
  const d = M.makeDefaultDoc();
  assert.deepEqual(d.screens.map((s) => s.id), ["hud", "bag", "stats", "perks", "map"]);
  assert.deepEqual(d.screens.map((s) => s.title), ["HUD", "Сумка", "Характеристики", "Древо", "Карта"]);
});

t("шаблон HUD: 17 елементів, «Удар» із кільцем 156/4 кути", () => {
  const hud = M.findScreen(M.makeDefaultDoc(), "hud");
  assert.equal(hud.elements.length, 17);
  const atk = hud.elements.find((e) => e.id === "attack");
  assert.deepEqual(atk.ring, { dist: 156, angles: [172, 212, 252, 292] });
  assert.equal(hud.elements.find((e) => e.id === "skill0").rel.parent, "attack");
});

t("addElement: тип, розмір із палітри, позиція в точці", () => {
  const d = M.makeDefaultDoc();
  const id = M.addElement(d, "bag", "slot", { x: 400, y: 400 });
  const el = M.findElement(d, "bag", id);
  assert.equal(el.type, "slot");
  assert.equal(el.o.r - el.o.l, 68);
  assert.equal(el.o.b - el.o.t, 68);
  assert.deepEqual([el.o.l, el.o.t, el.o.r, el.o.b], [400, 400, 468, 468]);
});

t("серіалізація ідемпотентна", () => {
  const d = M.makeDefaultDoc();
  const once = M.serialize(d);
  assert.equal(M.serialize(M.normalizeDoc(JSON.parse(once))), once);
});

t("битий вхід дає дефолтний документ, а не виняток", () => {
  for (const bad of [null, 42, [], { version: 99 }, { screens: "x" }]) {
    assert.doesNotThrow(() => M.normalizeDoc(bad));
    assert.ok(M.normalizeDoc(bad).screens.length >= 1);
  }
});

t("невідомі поля й невідомий тип переживають round-trip", () => {
  const raw = { version: 1, screens: [{ id: "x", title: "X", elements: [
    { id: "a", type: "btn", extra: { k: 1 }, a: { l: "l", t: "t", r: "l", b: "t" }, o: { l: 0, t: 0, r: 100, b: 40 } },
    { id: "b", type: "wat", a: { l: "l", t: "t", r: "l", b: "t" }, o: { l: 0, t: 0, r: 10, b: 10 } }
  ] }] };
  const out = M.normalizeDoc(JSON.parse(M.serialize(M.normalizeDoc(raw))));
  assert.deepEqual(out.screens[0].elements[0].extra, { k: 1 });
  assert.equal(out.screens[0].elements[1].type, "wat");
});

t("дублі id: лишається перший, другий отримує суфікс", () => {
  const raw = { version: 1, screens: [{ id: "x", title: "X", elements: [
    { id: "a", type: "btn", text: "1" },
    { id: "a", type: "btn", text: "2" }
  ] }] };
  const els = M.normalizeDoc(raw).screens[0].elements;
  assert.deepEqual(els.map((e) => e.id), ["a", "a2"]);
  assert.deepEqual(els.map((e) => e.text), ["1", "2"]);
});

t("розміри за замовчуванням: attack 160, skill 96, btn 250×58", () => {
  assert.deepEqual(M.widgetDefault("attack"), { w: 160, h: 160, text: "Удар" });
  assert.equal(M.widgetDefault("skill").w, 96);
  assert.equal(M.widgetDefault("btn").w, 250);
  assert.equal(M.widgetDefault("wat"), null);
});


// ---------------------------------------------------------------- Task 3

const C1560 = { w: 1560, h: 720 };

t("«Удар» у HUD: центр vs.x−136 / vs.y−126", () => {
  const hud = M.findScreen(M.makeDefaultDoc(), "hud");
  const r = M.resolvePositions(hud, C1560).get("attack");
  assert.deepEqual(r, { x: 1344, y: 514, w: 160, h: 160 });
});

t("навичка skill0 на 172°, радіус 156", () => {
  const hud = M.findScreen(M.makeDefaultDoc(), "hud");
  const r = M.resolvePositions(hud, C1560).get("skill0");
  assert.ok(Math.abs(r.x + 48 - 1269.52) < 0.6, "x центру " + (r.x + 48));
  assert.ok(Math.abs(r.y + 48 - 615.71) < 0.6, "y центру " + (r.y + 48));
  assert.equal(r.w, 96);
});

t("зілля: зсув від центру «Удару»", () => {
  const hud = M.findScreen(M.makeDefaultDoc(), "hud");
  const p = M.resolvePositions(hud, C1560).get("potion_hp");
  assert.equal(p.x + 34, 1488);
  assert.equal(p.y + 34, 348);
});

t("тягнута панель деталей Древа: 360×612, права прив'язка", () => {
  const perks = M.findScreen(M.makeDefaultDoc(), "perks");
  const r = M.resolvePositions(perks, C1560).get("detail");
  assert.deepEqual(r, { x: 1188, y: 92, w: 360, h: 612 });
});

t("зсув краю протилежний на 1280", () => {
  const perks = M.findScreen(M.makeDefaultDoc(), "perks");
  const r = M.resolvePositions(perks, { w: 1280, h: 720 }).get("detail");
  assert.deepEqual(r, { x: 908, y: 92, w: 360, h: 612 });
});

t("формула круга — центр", () => {
  const hud = M.findScreen(M.makeDefaultDoc(), "hud");
  const s = M.formulaText(hud.elements.find((e) => e.id === "attack"), C1560, M.resolvePositions(hud, C1560));
  assert.ok(s.includes("центр"), s);
  assert.ok(s.includes("x = vs.x - 136"), s);
  assert.ok(s.includes("y = vs.y - 126"), s);
});

t("формула круга з лівого краю", () => {
  const hud = M.findScreen(M.makeDefaultDoc(), "hud");
  const s = M.formulaText(hud.elements.find((e) => e.id === "stick"), C1560, M.resolvePositions(hud, C1560));
  assert.ok(s.includes("центр"), s);
  assert.ok(s.includes("vs.x + 186"), s);
});

t("формула тягнутого по висоті — від і до", () => {
  const perks = M.findScreen(M.makeDefaultDoc(), "perks");
  const s = M.formulaText(perks.elements.find((e) => e.id === "detail"), C1560, M.resolvePositions(perks, C1560));
  assert.ok(s.includes("vs.x - 372"), s);
  assert.ok(s.includes("360×612"), s);
  assert.ok(s.includes("vs.y + 92"), s);
  assert.ok(s.includes("vs.y - 16"), s);
});

t("кастомне полотно 4000×720 не ламає геометрію", () => {
  const hud = M.findScreen(M.makeDefaultDoc(), "hud");
  const r = M.resolvePositions(hud, { w: 4000, h: 720 }).get("attack");
  assert.equal(r.x, 4000 - 216);
  assert.equal(r.w, 160);
});


// ---------------------------------------------------------------- Task 4

function codesFor(doc, elId) {
  return M.validateDoc(doc)
    .filter((i) => i.elId === elId)
    .map((i) => i.code)
    .sort();
}

t("чистий шаблон не має помилок", () => {
  const errs = M.validateDoc(M.makeDefaultDoc()).filter((i) => i.level === "error");
  assert.deepEqual(errs, []);
});

t("малий інтерактивний елемент ловиться", () => {
  const d = M.makeDefaultDoc();
  M.findElement(d, "hud", "attack").o = { l: -216, t: -206, r: -196, b: -186 };
  assert.ok(codesFor(d, "attack").includes("small_target"));
});

t("вихід за екран рахується на 16:9, а не на 19.5:9", () => {
  const d = M.makeDefaultDoc();
  const loc = M.findElement(d, "hud", "loc");
  loc.a = { l: "l", t: "t", r: "l", b: "t" };
  loc.o = { l: 1100, t: 14, r: 1350, b: 40 };
  const presets = M.validateDoc(d)
    .filter((i) => i.elId === "loc" && i.code === "offscreen")
    .map((i) => i.presetId);
  assert.deepEqual([...new Set(presets)], ["16:9"]);
});

t("перетин двох кнопок — warn, слот усередині панелі — ні", () => {
  const d = M.makeDefaultDoc();
  const a = M.addElement(d, "bag", "btn", { x: 300, y: 300 });
  M.addElement(d, "bag", "btn", { x: 320, y: 320 });
  const slot = M.addElement(d, "bag", "slot", { x: 1250, y: 300 });
  assert.ok(codesFor(d, a).includes("overlap"));
  assert.ok(!codesFor(d, slot).includes("overlap"));
});

t("безпечна зона 36", () => {
  const d = M.makeDefaultDoc();
  const el = M.addElement(d, "bag", "btn", { x: 4, y: 4 });
  assert.ok(codesFor(d, el).includes("safe_zone"));
});

t("rel на неіснуючий батько — error, але елемент рахується абсолютно", () => {
  const d = M.makeDefaultDoc();
  const el = M.findElement(d, "hud", "skill0");
  el.rel = { parent: "nope", angle: 10 };
  assert.ok(codesFor(d, "skill0").includes("missing_parent"));
  const hud = M.findScreen(d, "hud");
  assert.ok(M.resolvePositions(hud, { w: 1560, h: 720 }).has("skill0"));
});

t("кільце замалого радіуса перекриває «Удар»", () => {
  const d = M.makeDefaultDoc();
  M.findElement(d, "hud", "attack").ring.dist = 80;
  assert.ok(codesFor(d, "skill0").includes("ring_overlap"));
});


// ---------------------------------------------------------------- Task 5

t("setElementRect переводить прямокутник у прив'язку право-низ", () => {
  const d = M.makeDefaultDoc();
  M.setElementRect(d, "hud", "attack", { x: 1300, y: 500, w: 160, h: 160 }, C1560);
  assert.deepEqual(M.findElement(d, "hud", "attack").a, { l: "r", t: "b", r: "r", b: "b" });
  assert.deepEqual(M.findElement(d, "hud", "attack").o, { l: -260, t: -220, r: -100, b: -60 });
});

t("ресайз тягнутої панелі зберігає ліві якорі", () => {
  const d = M.makeDefaultDoc();
  M.setElementRect(d, "perks", "detail", { x: 1150, y: 100, w: 380, h: 590 }, C1560);
  const el = M.findElement(d, "perks", "detail");
  assert.equal(el.a.l, "r");
  assert.equal(el.o.l, -410);
  assert.equal(el.o.r, -30);
  assert.equal(el.a.t, "t");
  assert.equal(el.o.t, 100);
  assert.equal(el.o.b, -30);
});

t("перетягнув упритул до лівого краю — якір стає l", () => {
  const d = M.makeDefaultDoc();
  M.setElementRect(d, "hud", "attack", { x: 8, y: 500, w: 160, h: 160 }, C1560);
  assert.equal(M.findElement(d, "hud", "attack").a.l, "l");
  assert.equal(M.findElement(d, "hud", "attack").a.r, "l");
});

t("ширина ≤ 0 затискається до 8, елемент живий", () => {
  const d = M.makeDefaultDoc();
  M.setElementRect(d, "hud", "attack", { x: 500, y: 300, w: -40, h: -10 }, C1560);
  const r = M.resolvePositions(M.findScreen(d, "hud"), C1560).get("attack");
  assert.equal(r.w, 8);
  assert.equal(r.h, 8);
});

t("snapEdge тягне до цілі в межах 6", () => {
  assert.equal(M.snapEdge(103, [100], 6), 100);
  assert.equal(M.snapEdge(110, [100], 6), 110);
  assert.equal(M.snapEdge(110, [100, 111], 6), 111);
});

t("setElement міняє текст, z і видимість, не чіпаючи геометрію", () => {
  const d = M.makeDefaultDoc();
  const before = JSON.stringify(M.findElement(d, "hud", "loc").o);
  M.setElement(d, "hud", "loc", { text: "Ліс", z: 9, visible: false });
  assert.equal(M.findElement(d, "hud", "loc").text, "Ліс");
  assert.equal(M.findElement(d, "hud", "loc").z, 9);
  assert.equal(M.findElement(d, "hud", "loc").visible, false);
  assert.equal(JSON.stringify(M.findElement(d, "hud", "loc").o), before);
});

t("guessAnchors бере найближчий край, а не центр", () => {
  const a = M.guessAnchors({ x: 600, y: 300, w: 160, h: 160 }, C1560);
  assert.deepEqual(a, { l: "l", t: "b", r: "l", b: "b" });
});

t("тягнуті осі не переграються при ресайзі", () => {
  const d = M.makeDefaultDoc();
  M.setElementRect(d, "perks", "detail", { x: 1000, y: 50, w: 500, h: 600 }, C1560);
  assert.deepEqual(M.findElement(d, "perks", "detail").a, { l: "r", t: "t", r: "r", b: "b" });
});

t("перенесення навички змінює кут, а не абсолютну позицію", () => {
  const d = M.makeDefaultDoc();
  const hud = M.findScreen(d, "hud");
  const atk = M.resolvePositions(hud, C1560).get("attack");
  // ставимо skill0 над «Ударом»
  M.setElementRect(d, "hud", "skill0", { x: atk.x + 32, y: atk.y - 200, w: 96, h: 96 }, C1560);
  const skill = M.findElement(d, "hud", "skill0");
  assert.equal(skill.rel.parent, "attack");
  assert.ok(Math.abs(skill.rel.angle + 90) < 2, "кут " + skill.rel.angle);
});


// ---------------------------------------------------------------- Task 6

t("інспектор: зміна w тягне лише правий відступ", () => {
  const d = M.makeDefaultDoc();
  M.applyInspector(d, "hud", "attack", "w", 200, C1560);
  const el = M.findElement(d, "hud", "attack");
  assert.equal(el.o.r - el.o.l, 200);
  assert.equal(el.o.l, -216);
});

t("інспектор: зміна x переставляє елемент, якір той самий", () => {
  const d = M.makeDefaultDoc();
  M.applyInspector(d, "hud", "attack", "x", 1200, C1560);
  const el = M.findElement(d, "hud", "attack");
  assert.equal(el.o.l, -360);
  assert.equal(el.a.l, "r");
});

t("інспектор: якір «ліво» перераховує відступ", () => {
  const d = M.makeDefaultDoc();
  M.applyInspector(d, "hud", "attack", "anchorL", "l", C1560);
  M.applyInspector(d, "hud", "attack", "anchorR", "l", C1560);
  const el = M.findElement(d, "hud", "attack");
  assert.equal(el.a.l, "l");
  assert.equal(el.o.l, 1344);
  assert.equal(el.o.r, 1504);
});

t("інспектор: текст і прихованість", () => {
  const d = M.makeDefaultDoc();
  M.applyInspector(d, "hud", "loc", "text", "Болото", C1560);
  M.applyInspector(d, "hud", "loc", "visible", false, C1560);
  assert.equal(M.findElement(d, "hud", "loc").text, "Болото");
  assert.equal(M.findElement(d, "hud", "loc").visible, false);
});

t("інспектор: z і замок", () => {
  const d = M.makeDefaultDoc();
  M.applyInspector(d, "hud", "minimap", "z", 9, C1560);
  M.applyInspector(d, "hud", "minimap", "locked", true, C1560);
  assert.equal(M.findElement(d, "hud", "minimap").z, 9);
  assert.equal(M.findElement(d, "hud", "minimap").locked, true);
});


// ---------------------------------------------------------------- Task 7

t("дубль екрана дає варіант із тими самими елементами, але новими id", () => {
  const d = M.makeDefaultDoc();
  M.duplicateScreen(d, "hud", "HUD v2");
  const copy = d.screens[d.screens.length - 1];
  assert.equal(copy.title, "HUD v2");
  assert.equal(copy.elements.length, 17);
  assert.equal(copy.id, "hud2");
  assert.notEqual(copy.elements[0].id, "top");
});

t("rel усередині копії вказує на копію, а не на оригінал", () => {
  const d = M.makeDefaultDoc();
  M.duplicateScreen(d, "hud");
  const copy = d.screens[d.screens.length - 1];
  const skill = copy.elements.find((e) => e.type === "skill");
  assert.equal(skill.rel.parent, "attack");
  assert.ok(copy.elements.some((e) => e.id === "attack"));
  assert.equal(M.resolvePositions(copy, C1560).size, copy.elements.length);
});

t("новий екран додається порожнім, назва правиться", () => {
  const d = M.makeDefaultDoc();
  const id = M.addScreen(d, "custom", "Мій екран");
  const s = M.findScreen(d, id);
  assert.equal(s.title, "Мій екран");
  assert.deepEqual(s.elements, []);
  M.renameScreen(d, id, "Інша назва");
  assert.equal(M.findScreen(d, id).title, "Інша назва");
});

t("останній екран не видаляється", () => {
  const d = M.makeDefaultDoc();
  for (const s of d.screens.slice(1)) M.deleteScreen(d, s.id);
  assert.equal(d.screens.length, 1);
  assert.equal(M.deleteScreen(d, d.screens[0].id), false);
  assert.equal(d.screens.length, 1);
});

t("дублікат елемента зсунутий на 8 і має новий id", () => {
  const d = M.makeDefaultDoc();
  const ids = M.duplicateElements(d, "hud", ["attack"]);
  const el = M.findElement(d, "hud", ids[0]);
  assert.notEqual(ids[0], "attack");
  assert.equal(el.o.l, -208);
  assert.equal(el.o.t, -198);
});

t("видалення елемента лишає rel сирітським, але не падає", () => {
  const d = M.makeDefaultDoc();
  M.removeElements(d, "hud", ["attack"]);
  assert.equal(M.findElement(d, "hud", "attack"), null);
  assert.equal(M.findElement(d, "hud", "skill0").rel.parent, "attack");
  assert.ok(M.validateDoc(d).some((i) => i.code === "missing_parent"));
});

t("z-порядок: вгору, вниз, і не вище 99", () => {
  const d = M.makeDefaultDoc();
  const loc = M.findElement(d, "hud", "loc");
  const z0 = loc.z;
  M.reorderZ(d, "hud", "loc", 1);
  assert.equal(M.findElement(d, "hud", "loc").z, z0 + 1);
  M.reorderZ(d, "hud", "loc", -1);
  assert.equal(M.findElement(d, "hud", "loc").z, z0);
  M.findElement(d, "hud", "loc").z = 99;
  M.reorderZ(d, "hud", "loc", 1);
  assert.equal(M.findElement(d, "hud", "loc").z, 99);
});

t("вирівнювання по лівому краю тягне всіх на min x", () => {
  const d = M.makeDefaultDoc();
  const a = M.addElement(d, "bag", "btn", { x: 300, y: 300 });
  const b = M.addElement(d, "bag", "btn", { x: 500, y: 400 });
  M.alignSelection(d, "bag", [a, b], "left");
  const ra = M.resolvePositions(M.findScreen(d, "bag"), C1560).get(a);
  const rb = M.resolvePositions(M.findScreen(d, "bag"), C1560).get(b);
  assert.equal(ra.x, 300);
  assert.equal(rb.x, 300);
  assert.equal(rb.y, 400);
});

t("копіювання між екранами: нові id, зсув 8, rel без батька відкидається", () => {
  const d = M.makeDefaultDoc();
  const clip = M.copyElements(d, "hud", ["skill0", "attack"]);
  const ids = M.pasteElements(d, "bag", clip);
  assert.equal(ids.length, 2);
  const bag = M.findScreen(d, "bag");
  assert.ok(ids.every((id) => !!M.findElement(d, "bag", id)));
  assert.equal(new Set(bag.elements.map((e) => e.id)).size, bag.elements.length);
  assert.equal(M.findElement(d, "bag", ids[0]).type, "skill");
  const lonely = M.copyElements(d, "hud", ["potion_hp"]);
  const loneId = M.pasteElements(d, "bag", lonely)[0];
  assert.equal(M.findElement(d, "bag", loneId).rel, undefined);
});


// ---------------------------------------------------------------- Task 8

t("історія: undo/redo повертає документи по черзі", () => {
  const h = M.createHistory(50);
  const d = M.makeDefaultDoc();
  h.push(d);
  M.setElement(d, "hud", "loc", { text: "Раз" });
  h.push(d);
  M.setElement(d, "hud", "loc", { text: "Два" });
  h.push(d);
  assert.equal(M.findElement(h.undo(), "hud", "loc").text, "Раз");
  assert.equal(M.findElement(h.undo(), "hud", "loc").text, "Селище");
  assert.equal(M.findElement(h.redo(), "hud", "loc").text, "Раз");
});

t("історія: ліміт 50 викидає найстаріше", () => {
  const h = M.createHistory(50);
  const d = M.makeDefaultDoc();
  for (let i = 0; i < 60; i++) { d.screens[0].title = "T" + i; h.push(d); }
  assert.equal(h.size(), 50);
  assert.equal(h.undo().screens[0].title, "T58");
});

t("undo на порожній історії — null, без винятку", () => {
  const h = M.createHistory(50);
  assert.equal(h.undo(), null);
  assert.equal(h.redo(), null);
});

t("повторний push того самого стану не плодить кроки", () => {
  const h = M.createHistory(50);
  const d = M.makeDefaultDoc();
  h.push(d);
  h.push(d);
  assert.equal(h.size(), 1);
});


// ---------------------------------------------------------------- Task 9

t("лічильник помилок і попереджень", () => {
  const issues = [
    { code: "offscreen", level: "error" }, { code: "overlap", level: "warn" }, { code: "safe_zone", level: "warn" }
  ];
  assert.deepEqual(M.countByLevel(issues), { error: 1, warn: 2 });
});

t("порожній список дає нулі", () => {
  assert.deepEqual(M.countByLevel([]), { error: 0, warn: 0 });
});


// ---------------------------------------------------------------- Task 10

t("поріг вбудови фону — 600 КБ", () => {
  assert.equal(M.bgPolicy(500000), "embed");
  assert.equal(M.bgPolicy(600000), "embed");
  assert.equal(M.bgPolicy(600001), "local");
});

t("важкий фон не потрапляє в JSON", () => {
  const d = M.makeDefaultDoc();
  M.setBackground(d, "hud", { dataUrl: "data:image/png;base64," + "A".repeat(700000), opacity: 0.5 });
  assert.equal(M.findScreen(d, "hud").bg, null);
  assert.ok(!M.serialize(d).includes("A".repeat(200)));
});

t("легкий фон вбудовується й повертається з JSON", () => {
  const d = M.makeDefaultDoc();
  M.setBackground(d, "hud", { dataUrl: "data:image/png;base64,QUJD", opacity: 0.4 });
  const out = M.normalizeDoc(JSON.parse(M.serialize(d)));
  assert.equal(M.findScreen(out, "hud").bg.opacity, 0.4);
  assert.ok(M.findScreen(out, "hud").bg.dataUrl.endsWith("QUJD"));
});

t("прибирання фону", () => {
  const d = M.makeDefaultDoc();
  M.setBackground(d, "hud", { dataUrl: "data:image/png;base64,QUJD", opacity: 0.4 });
  M.setBackground(d, "hud", null);
  assert.equal(M.findScreen(d, "hud").bg, null);
});


// ---------------------------------------------------------------- Task 11

t("опис містить «Удар», навичку й зілля у зрозумілому вигляді", () => {
  const s = M.summaryText(M.makeDefaultDoc());
  const line = s.split("\n").find((l) => l.startsWith("attack "));
  assert.ok(line, "немає рядка attack");
  assert.ok(line.includes("160×160"), line);
  assert.ok(line.includes("центр: x = vs.x - 136"), line);
  assert.ok(line.includes("y = vs.y - 126"), line);
  const sk = s.split("\n").find((l) => l.startsWith("skill0 "));
  assert.ok(sk.includes("172°"), sk);
  assert.ok(sk.includes("156"), sk);
  const po = s.split("\n").find((l) => l.startsWith("potion_hp "));
  assert.ok(po.includes("+64"), po);
  assert.ok(po.includes("-246"), po);
});

t("опис починається з заголовка екрана й пресета", () => {
  const s = M.summaryText(M.makeDefaultDoc());
  assert.ok(s.startsWith("HUD · 1560×720"), s.slice(0, 40));
  assert.ok(s.includes("Сумка · 1560×720"));
});

t("імпорт: експорт→імпорт дає той самий опис", () => {
  const d = M.makeDefaultDoc();
  const back = M.normalizeDoc(JSON.parse(M.serialize(d)));
  assert.equal(M.summaryText(back), M.summaryText(d));
});

t("опис не залежить від порядку елементів у масиві", () => {
  const d = M.makeDefaultDoc();
  d.screens[0].elements.reverse();
  assert.equal(M.summaryText(d), M.summaryText(M.makeDefaultDoc()));
});


// ---------------------------------------------------------------- регресія

t("після round-trip шаблон не має помилок (тягнуті осі не стискаються)", () => {
  const d = M.normalizeDoc(JSON.parse(M.serialize(M.makeDefaultDoc())));
  const errs = M.validateDoc(d).filter((i) => i.level === "error");
  assert.deepEqual(errs.map((i) => i.elId), []);
});

t("тягнута панель переживає export→import", () => {
  const d = M.normalizeDoc(JSON.parse(M.serialize(M.makeDefaultDoc())));
  const frame = M.findScreen(d, "bag").elements.find((e) => e.id === "frame");
  assert.deepEqual(frame.a, { l: "l", t: "t", r: "r", b: "b" });
  const r = M.resolvePositions(M.findScreen(d, "bag"), C1560).get("frame");
  assert.equal(r.w, 1540);
  assert.equal(r.h, 700);
});


t("навички на кільці не вважаються перетином (кола, а не прямокутники)", () => {
  const d = M.makeDefaultDoc();
  const ov = M.validateDoc(d).filter((i) => i.code === "overlap");
  assert.deepEqual([...new Set(ov.map((i) => i.elId))], []);
});

t("дві навички в одній точці — перетин", () => {
  const d = M.makeDefaultDoc();
  const s1 = M.findElement(d, "hud", "skill1");
  s1.rel = { parent: "attack", angle: 172 };
  const ov = M.validateDoc(d).filter((i) => i.code === "overlap");
  assert.ok(ov.length > 0);
});


t("розподіл по рівних проміжках", () => {
  const d = M.makeDefaultDoc();
  const a = M.addElement(d, "bag", "btn", { x: 100, y: 300 });
  const b = M.addElement(d, "bag", "btn", { x: 300, y: 400 });
  const c = M.addElement(d, "bag", "btn", { x: 900, y: 500 });
  M.distributeSelection(d, "bag", [a, b, c], "x");
  const pos = M.resolvePositions(M.findScreen(d, "bag"), C1560);
  assert.equal(pos.get(a).x, 100);
  assert.equal(pos.get(b).x, 500);
  assert.equal(pos.get(c).x, 900);
});

t("розподіл по вертикалі не чіпає X", () => {
  const d = M.makeDefaultDoc();
  const a = M.addElement(d, "bag", "btn", { x: 100, y: 100 });
  const b = M.addElement(d, "bag", "btn", { x: 200, y: 300 });
  const c = M.addElement(d, "bag", "btn", { x: 300, y: 900 });
  M.distributeSelection(d, "bag", [a, b, c], "y");
  const pos = M.resolvePositions(M.findScreen(d, "bag"), C1560);
  assert.equal(pos.get(a).x, 100);
  assert.equal(pos.get(b).x, 200);
  assert.equal(pos.get(a).y, 100);
  assert.ok(pos.get(b).y > 100);
});

console.log(fails ? "Є ПОМИЛКИ" : "ВСЕ ГАРАЗД");
process.exit(fails ? 1 : 0);
