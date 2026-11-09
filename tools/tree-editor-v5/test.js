/* Тест редактора v5 у jsdom: завантаження, рендер, мутації, експорт, перевірка. */
const fs = require("fs");
const path = require("path");
const { JSDOM } = require("jsdom");

const HTML = fs.readFileSync(path.join(__dirname, "index.html"), "utf8");
const TREE = JSON.parse(fs.readFileSync(path.join(__dirname, "../../data/perk_tree.json"), "utf8"));

let fails = 0;
const ok = (cond, msg) => { console.log((cond ? "  ok   " : "  FAIL ") + msg); if (!cond) fails++; };

const errors = [];
const vc = new (require("jsdom").VirtualConsole)();
vc.on("jsdomError", (e) => errors.push(e.message));
vc.on("error", (m) => errors.push(String(m)));

const dom = new JSDOM(HTML, {
  runScripts: "dangerously",
  pretendToBeVisual: true,
  url: "http://localhost/",
  virtualConsole: vc
});
const w = dom.window;

// стабільний прямокутник полотна, щоб fitAll мав сенс
const stage = w.document.getElementById("stage");
stage.getBoundingClientRect = () => ({ left: 0, top: 0, width: 1000, height: 700,
  right: 1000, bottom: 700, x: 0, y: 0 });

setTimeout(() => {
  console.log("== старт ==");
  ok(errors.length === 0, "жодних помилок при завантаженні" + (errors.length ? ": " + errors[0] : ""));

  console.log("== дані ==");
  w.eval(`S.data = normalizeData(${JSON.stringify(TREE)}); rebuildIndex(); renderAll(); fitAll(); updateFooter();`);
  const n = w.eval("S.data.nodes.length");
  const l = w.eval("S.data.links.length");
  ok(n === TREE.nodes.length, `вузлів у моделі: ${n}`);
  ok(l === TREE.links.length, `зв'язків у моделі: ${l}`);
  ok(w.document.querySelectorAll("#gNodes .node").length === n, "вузлів у DOM стільки ж: " + n);
  ok(w.document.querySelectorAll("#gLinks .link").length === l, "зв'язків у DOM стільки ж: " + l);

  console.log("== геометрія ==");
  const k = w.eval("S.view.k");
  ok(k > 0.004 && k < 4, "масштаб після fit у межах: " + k.toFixed(4));
  const tr = w.document.querySelector("#gNodes .node").getAttribute("transform");
  ok(/translate\(-?\d/.test(tr), "вузол має transform: " + tr);

  console.log("== виділення й редагування ==");
  const firstId = w.eval("S.data.nodes[0].id");
  w.eval(`selectOnly(${JSON.stringify(firstId)})`);
  ok(w.eval("S.sel.size") === 1, "виділено один вузол");
  w.eval(`setNodeField(${JSON.stringify(firstId)}, "name", "ТЕСТ")`);
  ok(w.eval(`S.nodeById.get(${JSON.stringify(firstId)}).name`) === "ТЕСТ", "назва змінюється");

  console.log("== додавання / видалення / undo ==");
  const before = w.eval("S.data.nodes.length");
  w.eval(`addNodeAt(12345, 54321)`);
  ok(w.eval("S.data.nodes.length") === before + 1, "вузол додано");
  w.eval("deleteSelected()");
  ok(w.eval("S.data.nodes.length") === before, "вузол видалено");
  w.eval("undo()");
  ok(w.eval("S.data.nodes.length") === before + 1, "undo повернув вузол");
  w.eval("redo()");
  ok(w.eval("S.data.nodes.length") === before, "redo прибрав його знову");

  console.log("== зв'язки ==");
  const ids = w.eval(`(() => {
    const a = S.data.nodes[0].id;
    for (const n of S.data.nodes) {
      if (n.id !== a && !S.linkByKey.has(linkKey(a, n.id))) return [a, n.id];
    }
    return [S.data.nodes[0].id, S.data.nodes[1].id];
  })()`);
  const l0 = w.eval("S.data.links.length");
  w.eval(`addLink(${JSON.stringify(ids[0])}, ${JSON.stringify(ids[1])})`);
  ok(w.eval("S.data.links.length") === l0 + 1, "зв'язок додано");
  const dup = w.eval(`addLink(${JSON.stringify(ids[0])}, ${JSON.stringify(ids[1])})`);
  ok(w.eval("S.data.links.length") === l0 + 1, "дубль зв'язку не додається");

  console.log("== перевірка ==");
  const iss = w.eval("computeIssues()");
  ok(Array.isArray(iss) && iss.length >= 0, "computeIssues повертає масив: " + iss.length);
  w.eval(`S.data.nodes.push({id:"bad1",name:"x",x:0,y:0,type:"small",region:"str",stats:{},description:""});
          S.data.links.push(["bad1","nonexistent"]); rebuildIndex();`);
  const iss2 = w.eval("computeIssues()");
  ok(iss2.some((i) => /неіснуючий/.test(i.msg)), "ловить зв'язок на неіснуючий вузол");

  console.log("== експорт ==");
  const out = JSON.parse(w.eval("JSON.stringify(S.data, null, 2)"));
  ok(out.format === "spohady-perk-tree", "format збережено");
  ok(out.version === 4, "version 4");
  ok(Array.isArray(out.regions) && out.regions.length === 3, "три регіони");
  ok(typeof out.class_starts === "object", "class_starts на місці");

  console.log("== фільтри й пошук ==");
  w.eval(`S.q = "Гнів"; applyFilters();`);
  const hidden = w.document.querySelectorAll("#gNodes .node.hidden").length;
  ok(hidden > 0, "пошук ховає частину вузлів: " + hidden);
  w.eval(`S.q = ""; applyFilters();`);
  ok(w.document.querySelectorAll("#gNodes .node.hidden").length === 0, "скидання пошуку показує все");

  console.log("== продуктивність рендера ==");
  const t0 = Date.now();
  w.eval("renderAll()");
  const dt = Date.now() - t0;
  ok(dt < 4000, `повний рендер ${n} вузлів: ${dt} мс`);

  console.log(fails === 0 ? "\nВСЕ ГАРАЗД" : `\nПОМИЛОК: ${fails}`);
  process.exit(fails === 0 ? 0 : 1);
}, 300);
