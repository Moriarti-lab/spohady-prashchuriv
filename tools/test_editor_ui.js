// Перевірка інтерфейсу редактора в jsdom (лише для розробки):
//   npm install jsdom --prefix /tmp/jd && NODE_PATH=/tmp/jd/node_modules node tools/test_editor_ui.js
const fs = require("fs"), path = require("path");
const { JSDOM } = require("jsdom");
const html = fs.readFileSync(path.join(__dirname, "tree-editor/index.html"), "utf8");
const noop = new Proxy(function () {}, { get: (t, k) => (k === "measureText" ? () => ({ width: 10 }) : noop), set: () => true, apply: () => noop });
const dom = new JSDOM(html, { runScripts: "dangerously", pretendToBeVisual: true, url: "http://localhost/",
  beforeParse(w) {
    w.HTMLCanvasElement.prototype.getContext = () => noop;
    w.Element.prototype.getBoundingClientRect = function () { return { left: 0, top: 0, width: 1000, height: 700, right: 1000, bottom: 700 }; };
    w.Element.prototype.setPointerCapture = function () {};
    w.URL.createObjectURL = () => "blob:x";
    w.confirm = () => true;
  } });
let n = 0, bad = 0;
function ok(c, w) { n++; console.log((c ? "  ok   " : "  FAIL ") + w); if (!c) bad++; }
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
(async function () {
  try {
    const win = dom.window, doc = win.document, ed = win.__editor;
    const cv = doc.getElementById("cv");
    function ev(type, id, x, y) {
      const e = new win.MouseEvent(type, { clientX: x, clientY: y, bubbles: true });
      Object.defineProperty(e, "pointerId", { value: id });
      cv.dispatchEvent(e);
    }
    const tapAt = async (x, y) => { ev("pointerdown", 1, x, y); ev("pointerup", 1, x, y); await sleep(5); };
    const btn = (re) => Array.from(doc.querySelectorAll("#dlgbox button")).filter((b) => re.test(b.textContent))[0];
    await sleep(50);
    ok(ed.data.nodes.length === 91, "стартове Древо завантажено: " + ed.data.nodes.length);
    ok(ed.validate().errors.length === 0, "стартове Древо проходить перевірку");
    const before = ed.data.nodes.length, links0 = ed.data.links.length;
    doc.getElementById("bFit").click();
    // вигляд після fit() відомий з формул
    const xs = ed.data.nodes.map((q) => q.x), ys = ed.data.nodes.map((q) => q.y);
    const x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys);
    const k = Math.max(0.05, Math.min(3, Math.min(1000 / (x1 - x0 + 160), 700 / (y1 - y0 + 160))));
    const vx = 500 - ((x0 + x1) / 2) * k, vy = 350 - ((y0 + y1) / 2) * k;
    const scr = (q) => [q.x * k + vx, q.y * k + vy];
    const byId = (id) => ed.data.nodes.filter((q) => q.id === id)[0];
    doc.querySelector('[data-mode="add"]').click();
    await tapAt(40, 40);
    ok(ed.data.nodes.length === before + 1, "режим «Вузол»: тап додає вузол");
    let added = ed.data.nodes[ed.data.nodes.length - 1];
    ok(doc.getElementById("f_id").value === added.id, "панель показує новий вузол");
    doc.querySelector('[data-mode="move"]').click();
    const ox = added.x, oy = added.y;
    ev("pointerdown", 1, 40, 40); ev("pointermove", 1, 100, 90); ev("pointermove", 1, 200, 150); ev("pointerup", 1, 200, 150);
    ok(added.x !== ox && added.y !== oy, `перетягування рухає вузол: (${ox},${oy}) → (${added.x},${added.y})`);
    const nm = doc.getElementById("f_name"); nm.value = "Мій вузол";
    nm.dispatchEvent(new win.Event("input")); nm.dispatchEvent(new win.Event("change"));
    ok(added.name === "Мій вузол", "назву змінено через панель");
    const typ = doc.querySelector("#side select"); typ.value = "notable"; typ.dispatchEvent(new win.Event("change"));
    ok(added.type === "notable", "тип змінено через панель");
    const a = scr(added), b = scr(byId("s_t0"));
    doc.querySelector('[data-mode="link"]').click();
    await tapAt(a[0], a[1]); await tapAt(b[0], b[1]);
    ok(ed.data.links.length === links0 + 1, "режим «Зв'язки»: два тапи додають зв'язок");
    await tapAt(a[0], a[1]); await tapAt(b[0], b[1]);
    ok(ed.data.links.length === links0, "повторні два тапи прибирають зв'язок");
    await tapAt(a[0], a[1]); await tapAt(b[0], b[1]);
    ok(ed.data.links.length === links0 + 1 && ed.validate().errors.length === 0, "Древо з новим вузлом проходить перевірку");
    doc.getElementById("bUndo").click();
    ok(ed.data.links.length === links0, "↶ скасовує останню дію");
    doc.getElementById("bRedo").click();
    ok(ed.data.links.length === links0 + 1, "↷ повертає дію");
    added = byId(added.id);
    // старт класу з новим id
    doc.querySelector('[data-mode="move"]').click();
    await tapAt(a[0], a[1]);
    const idIn = doc.getElementById("f_id"); idIn.value = "my_node"; idIn.dispatchEvent(new win.Event("change"));
    ok(added.id === "my_node" && ed.data.links.some((l) => l.includes("my_node")), "перейменування id оновлює зв'язки");
    const s0 = scr(byId("s_t0"));
    await tapAt(s0[0], s0[1]);
    idIn.value = "my_start"; doc.getElementById("f_id").value = "my_start"; doc.getElementById("f_id").dispatchEvent(new win.Event("change"));
    ok(ed.data.class_starts.druzhynnyk === "my_start" && ed.validate().errors.length === 0, "перейменування старту класу оновлює class_starts");
    await tapAt(a[0], a[1]);
    doc.querySelector("#side .danger").click();
    ok(ed.data.nodes.length === before && ed.data.links.length === links0, "вузол видалено разом із зв'язками");
    // пінч-масштаб
    ev("pointerdown", 2, 300, 300); ev("pointerdown", 3, 400, 300); ev("pointermove", 3, 600, 300); ev("pointerup", 3, 600, 300); ev("pointerup", 2, 300, 300);
    ok(ed.data.nodes.length === before, "пінч не ламає редактор");
    // експорт
    doc.getElementById("bIO").click();
    let ta = doc.querySelector("#dlgbox textarea");
    const exp = JSON.parse(ta.value);
    ok(exp.nodes.length === before && exp.format === "spohady-perk-tree" && exp.class_starts.druzhynnyk === "my_start", "експорт: поле JSON із " + before + " вузлами");
    ok(/Усе гаразд/.test(doc.getElementById("msgs").textContent), "експорт: перевірка «Усе гаразд»");
    // імпорт
    exp.nodes = exp.nodes.filter((q) => q.id !== "f_t5" && q.id !== "f_t4");
    exp.links = exp.links.filter((l) => !l.includes("f_t5") && !l.includes("f_t4"));
    ta.value = JSON.stringify(exp);
    btn(/Застосувати/).click();
    ok(ed.data.nodes.length === before - 2, "імпорт із поля: " + ed.data.nodes.length + " вузлів");
    // поганий імпорт
    doc.getElementById("bIO").click();
    ta = doc.querySelector("#dlgbox textarea"); ta.value = "{ це не json";
    btn(/Застосувати/).click();
    ok(ed.data.nodes.length === before - 2 && /Це не JSON/.test(doc.getElementById("msgs").textContent), "поганий JSON показує помилку й нічого не ламає");
    ta.value = JSON.stringify({ format: "spohady-perk-tree", version: 1, nodes: [{ id: "a" }], links: [] });
    btn(/Застосувати/).click();
    ok(ed.data.nodes.length === before - 2 && doc.querySelectorAll("#msgs .e").length > 0, "Древо з помилками не імпортується");
    btn(/Скинути/).click();
    ok(ed.data.nodes.length === 91, "скидання повертає стартове Древо");
    doc.getElementById("bCheck").click();
    ok(/Усе гаразд/.test(doc.getElementById("msgs").textContent), "діалог перевірки");
    doc.getElementById("bMeta").click();
    ok(doc.querySelectorAll("#dlgbox select").length === 3, "діалог класів: три вибори стартових вузлів");
    ok(doc.querySelectorAll("script[src], link[href]").length === 0, "жодних зовнішніх ресурсів");
    ok(ed.exportText().endsWith("\n") && JSON.parse(ed.exportText()).nodes.length === 91, "exportText() — JSON у форматі гри");
  } catch (e) { ok(false, "ВИНЯТОК: " + e.stack); }
  console.log("\nПідсумок: " + n + " перевірок, " + bad + " помилок");
  process.exit(bad ? 1 : 0);
})();
