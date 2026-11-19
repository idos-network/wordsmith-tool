// Renders scene.html frame by frame in headless Chrome over the DevTools protocol (no npm packages).
// Usage: node render.mjs frames <dir>            → every frame of the video, 30 fps
//        node render.mjs stills <dir> 0.5,6.8    → just these times, for checking
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const work = path.dirname(new URL(import.meta.url).pathname);
const [mode, outDir, timesArg] = process.argv.slice(2);
const FPS = 30, DURATION = 29;
const times = mode === "stills" ? timesArg.split(",").map(Number)
  : Array.from({ length: FPS * DURATION }, (_, i) => i / FPS);
fs.mkdirSync(path.join(work, outDir), { recursive: true });
fs.writeFileSync(path.join(work, "data.js"), `window.DATA = ${fs.readFileSync(path.join(work, "texts.json"), "utf8")};`);

const chrome = spawn("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", [
  "--headless=new", "--remote-debugging-port=9333", `--user-data-dir=${path.join(work, "chrome-profile")}`,
  "--hide-scrollbars", "--force-device-scale-factor=1", "--window-size=1920,1080", "--no-first-run",
  "--no-default-browser-check", "--allow-file-access-from-files", "about:blank",
], { stdio: "ignore" });
const sleep = ms => new Promise(r => setTimeout(r, ms));

try {
  let wsUrl;
  for (let i = 0; i < 100 && !wsUrl; i++) {
    try {
      const pages = await (await fetch("http://127.0.0.1:9333/json/list")).json();
      wsUrl = pages.find(p => p.type === "page")?.webSocketDebuggerUrl;
    } catch {}
    if (!wsUrl) await sleep(100);
  }
  if (!wsUrl) throw new Error("Chrome did not start");

  const ws = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  let nextId = 0;
  const pending = new Map();
  ws.onmessage = ({ data }) => {
    const msg = JSON.parse(data);
    if (!pending.has(msg.id)) return;
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
  };
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const { result, exceptionDetails } = await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
    if (exceptionDetails) throw new Error(JSON.stringify(exceptionDetails));
    return result.value;
  };

  await send("Emulation.setDeviceMetricsOverride", { width: 1920, height: 1080, deviceScaleFactor: 1, mobile: false });
  await send("Page.navigate", { url: "file://" + path.join(work, "scene.html") });
  for (let i = 0; i < 100 && !(await evaluate("window.ready === true").catch(() => false)); i++) await sleep(100);
  // fonts and every image must be decoded before the first capture
  await evaluate("(async () => { await document.fonts.ready; await Promise.all([...document.images].map(i => i.decode())); return true })()");

  for (const [index, t] of times.entries()) {
    await evaluate(`new Promise(r => { render(${t}); requestAnimationFrame(() => requestAnimationFrame(r)); })`);
    const { data } = await send("Page.captureScreenshot", { format: "png" });
    const name = mode === "stills" ? `still-${t.toFixed(2)}.png` : `${String(index).padStart(5, "0")}.png`;
    fs.writeFileSync(path.join(work, outDir, name), Buffer.from(data, "base64"));
    if (index % 60 === 0) console.log(`frame ${index}/${times.length}`);
  }
  ws.close();
} finally {
  chrome.kill();
}
