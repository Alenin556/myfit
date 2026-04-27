/**
 * iOS: заполняет AppIconDark.appiconset из app_icon_dark_1024.png (альтернативная иконка).
 * Run: node export_ios_alternate.mjs
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import sharp from "sharp";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "../..");
const srcPng = path.join(root, "assets", "icon", "export", "app_icon_dark_1024.png");
const appIcon = path.join(
  root,
  "ios",
  "Runner",
  "Assets.xcassets",
  "AppIcon.appiconset",
  "Contents.json",
);
const outDir = path.join(
  root,
  "ios",
  "Runner",
  "Assets.xcassets",
  "AppIconDark.appiconset",
);

const raw = JSON.parse(fs.readFileSync(appIcon, "utf8"));
const images = raw.images;
if (!Array.isArray(images)) {
  console.error("bad AppIcon Contents.json");
  process.exit(1);
}

if (!fs.existsSync(srcPng)) {
  console.error("missing", srcPng);
  process.exit(1);
}

if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

const buf = fs.readFileSync(srcPng);

for (const im of images) {
  if (!im.filename) continue;
  const sizeStr = im.size; // e.g. "20x20", "83.5x83.5"
  const [wStr, hStr] = String(sizeStr).toLowerCase().split("x");
  const w = parseFloat(wStr);
  const h = parseFloat(hStr);
  const base = Math.max(w, h) || 20;
  const scale = im.scale === "3x" ? 3 : im.scale === "2x" ? 2 : 1;
  const px = Math.round(base * scale);
  const out = path.join(outDir, im.filename);
  const png = await sharp(buf)
    .resize(px, px, { fit: "fill" })
    .png()
    .toBuffer();
  fs.writeFileSync(out, png);
  console.log("wrote", im.filename, px);
}

const cj = { ...raw, info: raw.info || { version: 1, author: "xcode" } };
fs.writeFileSync(path.join(outDir, "Contents.json"), JSON.stringify(cj, null, 2));
console.log("done AppIconDark");
