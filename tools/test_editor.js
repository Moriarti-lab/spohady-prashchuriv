// Перевірка ядра редактора (формат, валідація) без браузера: node tools/test_editor.js
const fs = require("fs"), path = require("path"), vm = require("vm"), assert = require("assert");
const root = path.dirname(__dirname);
const html = fs.readFileSync(path.join(root, "tools/tree-editor/index.html"), "utf8");
const core = html.split("/*CORE-START*/")[1].split("/*CORE-END*/")[0];
const ctx = {}; vm.createContext(ctx); vm.runInContext(core, ctx);
const embedded = JSON.parse(html.split('<script id="default-tree" type="application/json">')[1].split("</script>")[0]);
const file = JSON.parse(fs.readFileSync(path.join(root, "data/perk_tree.json"), "utf8"));
let n = 0, bad = 0;
function ok(c, what) { n++; if (!c) { bad++; console.log("  FAIL", what); } else console.log("  ok  ", what); }
const clone = (o) => JSON.parse(JSON.stringify(o));
const errs = (d) => ctx.validateTree(d).errors.length;

ok(JSON.stringify(embedded) === JSON.stringify(file), "вбудоване Древо == data/perk_tree.json");
const v = ctx.validateTree(file);
ok(v.errors.length === 0 && v.warnings.length === 0, "data/perk_tree.json проходить перевірку редактора " + JSON.stringify(v));
ok(file.nodes.length >= 250 && file.nodes.length <= 600, "вузлів 250–600: " + file.nodes.length);
ok((file.version === 3 || file.version === 4) && file.nodes.filter(n => n.type === "core").length === 1, "версія 3/4 і одне Серце роду");
ok(file.nodes.filter(n => n.skill || n.mod_skill).length === 0, "пасивне Древо без skill/mod_skill");
// експорт того, що читає редактор, дає той самий файл
const exported = JSON.parse(ctx.serializeTree({ format: file.format, version: file.version, title: file.title, comment: file.comment,
  regions: file.regions, class_starts: file.class_starts, nodes: file.nodes.map(ctx.normalizeNode), links: file.links }));
let same = true; try { assert.deepStrictEqual(exported, file); } catch (e) { same = false; console.log(String(e.message).slice(0, 600)); }
ok(same, "нормалізація + серіалізація не змінюють файл");
ok(ctx.serializeTree(file).endsWith("}\n") && ctx.serializeTree(file).startsWith('{\n "format"'), "формат запису: відступ 1, новий рядок у кінці");
// негативні випадки — ті самі, що в tests/smoke_test.gd
let d = clone(file); d.nodes.push({ id: "s_root", name: "Дубль", x: 0, y: 0, type: "small", stats: {} }); ok(errs(d) > 0, "дублікат id відхилено");
d = clone(file); d.links.push(["s_root", "немає_такого"]); ok(errs(d) > 0, "зв'язок з невідомим вузлом відхилено");
d = clone(file); d.links.push(["s_root", "s_root"]); ok(errs(d) > 0, "зв'язок вузла із собою відхилено");
d = clone(file); d.links.push(clone(file.links[0])); ok(errs(d) > 0, "повтор зв'язку відхилено");
d = clone(file); d.nodes[3].type = "чарівний"; ok(errs(d) > 0, "невідомий тип відхилено");
d = clone(file); d.nodes[3].stats = { "літання": 5 }; ok(errs(d) > 0, "невідомий бонус відхилено");
d = clone(file); d.nodes[3].stats = { str: "багато" }; ok(errs(d) > 0, "нечисловий бонус відхилено");
d = clone(file); delete d.class_starts.volkhv; ok(errs(d) > 0, "відсутній старт класу відхилено");
d = clone(file); d.class_starts.volkhv = "nope"; ok(errs(d) > 0, "старт на неіснуючий вузол відхилено");
d = clone(file); d.nodes[3].skill = "літати"; ok(errs(d) > 0, "невідома навичка відхилено");
d = clone(file); d.nodes[3].type = "skill"; d.nodes[3].skill = ""; ok(errs(d) > 0, "тип skill без навички відхилено");
d = clone(file); d.nodes[3].x = "ліворуч"; ok(errs(d) > 0, "нечислова координата відхилена");
d = clone(file); d.nodes[3].name = "  "; ok(errs(d) > 0, "порожня назва відхилена");
d = clone(file); d.nodes[3].id = "вузол 1"; ok(errs(d) > 0, "id з кирилицею/пробілом відхилено");
d = clone(file); d.format = "щось"; ok(errs(d) > 0, "хибний format відхилено");
d = clone(file); d.version = 99; ok(errs(d) > 0, "хибна version відхилена");
d = clone(file); d.nodes[3].mod_skill = "літати"; ok(errs(d) > 0, "невідома mod_skill відхилена");
d = clone(file); d.nodes[3].mod_skill = "power_strike"; d.nodes[3].mods = { літати: 3 }; ok(errs(d) > 0, "невідоме поліпшення відхилено");
d = clone(file); d.nodes[3].mod_skill = "power_strike"; d.nodes[3].mods = { dmg_pct: "багато" }; ok(errs(d) > 0, "нечислове поліпшення відхилено");
d = clone(file); d.nodes.find(n => n.type === "small").mods = { dmg_pct: 5 }; ok(errs(d) > 0, "mods без mod_skill відхилено");
d = clone(file); d.nodes.find(n => n.type === "small").starter = true; ok(errs(d) > 0, "starter на не-навичці відхилено");
d = clone(file); d.nodes.find(n => n.type === "small").starter = "так"; ok(errs(d) > 0, "starter не-булів відхилено");
ok(errs("текст") > 0 && errs(null) > 0 && errs([]) > 0, "не-об'єкт відхилено");
d = clone(file); d.nodes = []; ok(errs(d) > 0, "порожній список вузлів відхилено");
d = clone(file); d.nodes.push({ id: "island", name: "Острів", x: 5000, y: 5000, type: "small", stats: { str: 1 } });
ok(errs(d) === 0 && ctx.validateTree(d).warnings.length === 1, "недосяжний вузол — лише застереження");
d = clone(file); d.nodes[4].x = d.nodes[5].x; d.nodes[4].y = d.nodes[5].y; ok(ctx.validateTree(d).warnings.length >= 1, "вузли в одній точці — застереження");
// мінімальне Древо в мінімальному вигляді (необов'язкові поля можна пропустити)
const mini = { format: "spohady-perk-tree", version: 1, class_starts: { druzhynnyk: "a", strilets: "a", volkhv: "a" },
  nodes: [{ id: "a", name: "А", x: 0, y: 0, type: "start" }, { id: "b", name: "Б", x: 10, y: 0, type: "small", stats: { hp: 5 } }], links: [["a", "b"]] };
ok(errs(mini) === 0, "мінімальне Древо без description/stats/icon/region коректне");
console.log("\nПідсумок: " + n + " перевірок, " + bad + " помилок");
process.exit(bad ? 1 : 0);
