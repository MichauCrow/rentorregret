// Renderuje podglądy świata do PNG: node tools/preview/render.mjs [nazwa widoku...]
// Wymaga wcześniej: lune run tools/preview/export_world (pliki out/*.json).
import { createServer } from "node:http";
import { readFile, mkdir } from "node:fs/promises";
import { extname, join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const root = dirname(fileURLToPath(import.meta.url));
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".png": "image/png" };

const server = createServer(async (req, res) => {
  try {
    const path = join(root, decodeURIComponent(new URL(req.url, "http://x").pathname));
    res.writeHead(200, { "content-type": TYPES[extname(path)] || "application/octet-stream" });
    res.end(await readFile(path));
  } catch { res.writeHead(404); res.end(); }
});
await new Promise((resolve) => server.listen(0, resolve));
const port = server.address().port;

const { VIEWS } = await import("./views.mjs");
const wanted = process.argv.slice(2);
const browser = await chromium.launch({ args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
page.on("console", (m) => { if (m.type() === "error") console.log("[strona]", m.text()); });
page.on("pageerror", (e) => console.log("[błąd strony]", e.message));
await page.goto(`http://localhost:${port}/viewer.html`);
await page.waitForFunction("window.ready === true");
await mkdir(join(root, "out", "img"), { recursive: true });
let loaded = null;
for (const view of VIEWS) {
  if (wanted.length && !wanted.some((w) => view.name.includes(w))) continue;
  if (loaded !== view.scene) { await page.evaluate((s) => window.loadScene(s), view.scene); loaded = view.scene; }
  await page.evaluate((v) => window.setView(v), view);
  await page.screenshot({ path: join(root, "out", "img", view.name + ".png") });
  console.log("zapisano", view.name);
}
await browser.close();
server.close();
