// Składa zrzuty w jedną planszę: node tools/preview/montage.mjs <folder w out> <fragment nazwy> <kolumny> <plik wyjściowy>
import { createServer } from "node:http";
import { readFile, readdir } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const root = dirname(fileURLToPath(import.meta.url));
const [folder, filter, columns = "3", output = "montage.png"] = process.argv.slice(2);
const files = (await readdir(join(root, "out", folder))).filter((f) => f.endsWith(".png") && f.includes(filter)).sort();
const server = createServer(async (req, res) => {
  const path = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (path === "/") {
    res.writeHead(200, { "content-type": "text/html" });
    res.end(`<body style="margin:0;background:#222;display:grid;grid-template-columns:repeat(${columns},1fr);gap:4px;font:12px sans-serif;color:#fff">` + files.map((f) => `<div><div style="padding:2px 4px">${f}</div><img src="/${f}" style="width:100%;display:block"></div>`).join("") + "</body>");
    return;
  }
  try { res.writeHead(200, { "content-type": "image/png" }); res.end(await readFile(join(root, "out", folder, path))); } catch { res.writeHead(404); res.end(); }
});
await new Promise((resolve) => server.listen(0, resolve));
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 800 } });
await page.goto(`http://localhost:${server.address().port}/`);
await page.waitForLoadState("networkidle");
await page.screenshot({ path: join(root, "out", output), fullPage: true });
await browser.close();
server.close();
console.log("zapisano", output, files.length);
