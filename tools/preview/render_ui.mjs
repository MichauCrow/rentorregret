// Renderuje zrzuty interfejsu (z tests/test_client ... <folder>) do PNG przez HTML/CSS.
// node tools/preview/render_ui.mjs [fragment nazwy...]
// Przybliżenie: układ liczy CSS, czcionka to Fredoka One, a tłem jest podgląd świata z render.mjs.
import { createServer } from "node:http";
import { readFile, readdir, mkdir } from "node:fs/promises";
import { extname, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const root = dirname(fileURLToPath(import.meta.url));
const TYPES = { ".html": "text/html", ".png": "image/png", ".woff2": "font/woff2", ".json": "application/json" };
const TOPBAR = 58; // wysokość paska Roblox (ScreenGui bez IgnoreGuiInset zaczyna się pod nim)
const BACKGROUNDS = { lobby: "out/img/lobby_spawn.png", round: "out/img/eye_corridor_f1_night.png" };

const rgb = (c, a = 1) => `rgba(${Math.round(c[0] * 255)},${Math.round(c[1] * 255)},${Math.round(c[2] * 255)},${a})`;
const dim = (scale, offset) => (scale ? `calc(${scale * 100}% + ${offset}px)` : `${offset}px`);
const esc = (t) => String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;");
const kids = (n) => (Array.isArray(n.children) ? n.children : []);
const find = (n, cls) => kids(n).find((c) => c.class === cls);
const ALIGN = { Left: "flex-start", Center: "center", Right: "flex-end", Top: "flex-start", Bottom: "flex-end" };

function guiObject(node, flow) {
  if (!node.visible) return "";
  const corner = find(node, "UICorner"), stroke = find(node, "UIStroke"), list = find(node, "UIListLayout");
  const grid = find(node, "UIGridLayout"), pad = find(node, "UIPadding"), scale = find(node, "UIScale"), gradient = find(node, "UIGradient");
  const isText = node.text !== undefined;
  const style = [];
  const autoY = node.auto === "Y" || node.auto === "XY";
  if (flow) {
    style.push("position:relative", "flex:none", `order:${node.order}`);
    style.push(`width:${dim(node.size[0], node.size[1])}`);
    style.push(autoY ? `min-height:${node.size[3]}px` : `height:${dim(node.size[2], node.size[3])}`);
  } else {
    style.push("position:absolute", `left:${dim(node.pos[0], node.pos[1])}`, `top:${dim(node.pos[2], node.pos[3])}`);
    style.push(`width:${dim(node.size[0], node.size[1])}`);
    style.push(autoY ? `min-height:${node.size[3]}px` : `height:${dim(node.size[2], node.size[3])}`);
  }
  const transforms = [];
  if (!flow) transforms.push(`translate(${-node.anchor[0] * 100}%,${-node.anchor[1] * 100}%)`);
  if (node.rot) transforms.push(`rotate(${node.rot}deg)`);
  if (scale && scale.scale !== 1) transforms.push(`scale(${scale.scale})`);
  if (transforms.length) style.push(`transform:${transforms.join(" ")}`);
  style.push(`z-index:${node.z}`, "box-sizing:border-box");
  if (node.bgT < 1) {
    style.push(`background-color:${rgb(node.bg, 1 - node.bgT)}`);
    if (gradient && gradient.gloss) style.push("background-image:linear-gradient(to bottom,rgba(255,255,255,0.10),rgba(0,0,0,0.06) 50%,rgba(0,0,0,0.26))");
    else if (gradient) style.push(`-webkit-mask-image:linear-gradient(${gradient.rot + 90}deg,#000,transparent)`);
  }
  if (corner) style.push(`border-radius:${corner.radius}px`);
  const textStroke = stroke && isText && stroke.mode !== "Border";
  if (stroke && !textStroke) style.push(`box-shadow:0 0 0 ${stroke.thickness}px ${rgb(stroke.color)}`);
  if (pad) style.push(`padding:${pad.pad.map((p) => p + "px").join(" ")}`);
  const childFlow = Boolean(list || grid) || node.auto !== "None";
  if (list) {
    const column = list.dir === "Vertical";
    style.push("display:flex", `flex-direction:${column ? "column" : "row"}`, `gap:${list.padding}px`);
    style.push(`align-items:${ALIGN[column ? list.hAlign : list.vAlign]}`, `justify-content:${ALIGN[column ? list.vAlign : list.hAlign]}`);
  } else if (grid) {
    style.push("display:flex", "flex-wrap:wrap", `gap:${grid.padding[3]}px ${grid.padding[1]}px`, `justify-content:${ALIGN[grid.hAlign]}`, "align-content:flex-start");
  } else if (isText) {
    style.push("display:flex", `align-items:${ALIGN[node.yAlign]}`, `justify-content:${ALIGN[node.xAlign]}`);
  }
  let inner = "";
  if (isText && node.text !== "") {
    const t = [`color:${rgb(node.textColor, 1 - node.textT)}`, `font-size:${node.textSize}px`, `text-align:${node.xAlign.toLowerCase()}`];
    t.push(node.wrapped || node.scaled ? "white-space:pre-wrap" : "white-space:pre", "max-width:100%");
    if (textStroke) t.push(`-webkit-text-stroke:${stroke.thickness * 2}px ${rgb(stroke.color, 1 - node.textT)}`, "paint-order:stroke fill");
    inner += `<span class="t"${node.scaled ? ' data-scaled="1"' : ""} style="${t.join(";")}">${esc(node.text)}</span>`;
  }
  for (const child of kids(node)) {
    if (child.size === undefined) continue;
    let childNode = child;
    if (grid) childNode = { ...child, size: grid.cell };
    inner += guiObject(childNode, childFlow);
  }
  return `<div class="go" data-name="${esc(node.name)}" style="${style.join(";")}">${inner}</div>`;
}

function page(snapshot, font, background) {
  const screens = kids(snapshot.root).filter((n) => n.class === "ScreenGui" && n.enabled !== false).sort((a, b) => a.order - b.order);
  let body = "";
  for (const screen of screens) {
    const scale = find(screen, "UIScale");
    const s = scale ? scale.scale : 1;
    const top = screen.inset ? 0 : TOPBAR;
    const content = kids(screen).filter((c) => c.size !== undefined).map((c) => guiObject(c, false)).join("");
    body += `<div style="position:absolute;left:0;top:${top}px;width:100%;height:calc(100% - ${top}px);z-index:${screen.order};pointer-events:none">`
      + `<div style="position:absolute;left:0;top:0;width:${100 / s}%;height:${100 / s}%;transform:scale(${s});transform-origin:0 0">${content}</div></div>`;
  }
  // Elementy Roblox dla porównania: pasek u góry, a na telefonie gałka ruchu i przycisk skoku
  let chrome = `<div style="position:absolute;left:0;top:0;width:100%;height:${TOPBAR}px;background:rgba(0,0,0,0.25);z-index:999"></div>`
    + `<div style="position:absolute;left:12px;top:10px;width:86px;height:38px;border-radius:19px;background:rgba(20,20,24,0.8);z-index:1000"></div>`;
  if (snapshot.touch) {
    const jump = snapshot.height <= 500 ? 70 : 120;
    chrome += `<div style="position:absolute;right:${jump * 1.5 - 10 - jump}px;bottom:20px;width:${jump}px;height:${jump}px;border-radius:50%;background:rgba(255,255,255,0.35);border:2px solid #fff;z-index:1000"></div>`
      + `<div style="position:absolute;left:40px;bottom:30px;width:110px;height:110px;border-radius:50%;background:rgba(255,255,255,0.2);border:2px solid rgba(255,255,255,0.6);z-index:1000"></div>`;
  }
  return `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:"Fredoka One";src:url("${font}") format("woff2")}
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#111 url("${background}") center/cover}
.go{font-family:"Fredoka One","Noto Color Emoji",sans-serif;line-height:1.12}
.t{display:block}
</style></head><body>${body}${chrome}
<script>
for (const span of document.querySelectorAll('[data-scaled]')) {
  const box = span.parentElement; let lo = 4, hi = 100;
  for (let i = 0; i < 9; i++) { const mid = (lo + hi) / 2; span.style.fontSize = mid + 'px';
    if (span.scrollWidth <= box.clientWidth && span.offsetHeight <= box.clientHeight) lo = mid; else hi = mid; }
  span.style.fontSize = lo + 'px';
}
window.ready = true;
</script></body></html>`;
}

const pages = new Map();
const server = createServer(async (req, res) => {
  const path = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (pages.has(path)) { res.writeHead(200, { "content-type": "text/html" }); res.end(pages.get(path)); return; }
  try {
    const file = join(root, path);
    res.writeHead(200, { "content-type": TYPES[extname(file)] || "application/octet-stream" });
    res.end(await readFile(file));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise((resolve) => server.listen(0, resolve));
const base = `http://localhost:${server.address().port}`;
const wanted = process.argv.slice(2);
const files = (await readdir(join(root, "out", "ui"))).filter((f) => f.endsWith(".json")).sort();
await mkdir(join(root, "out", "ui_img"), { recursive: true });
const browser = await chromium.launch();
for (const file of files) {
  if (wanted.length && !wanted.some((w) => file.includes(w))) continue;
  const snapshot = JSON.parse(await readFile(join(root, "out", "ui", file), "utf8"));
  const name = file.replace(".json", "");
  pages.set(`/${name}.html`, page(snapshot, "/node_modules/@fontsource/fredoka-one/files/fredoka-one-latin-400-normal.woff2", "/" + (BACKGROUNDS[snapshot.background] || BACKGROUNDS.round)));
  const tab = await browser.newPage({ viewport: { width: snapshot.width, height: snapshot.height }, deviceScaleFactor: snapshot.width < 1000 ? 2 : 1 });
  tab.on("pageerror", (e) => console.log("[błąd strony]", e.message));
  await tab.goto(`${base}/${name}.html`);
  await tab.waitForFunction("window.ready === true");
  await tab.evaluate(() => document.fonts.ready);
  await tab.screenshot({ path: join(root, "out", "ui_img", name + ".png") });
  await tab.close();
  console.log("zapisano", name);
}
await browser.close();
server.close();
