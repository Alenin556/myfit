/**
 * Renders app_icon_*.svg to PNGs (TZ sizes: 1024…48).
 * Run: npm install && node export_png.mjs
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import sharp from "sharp";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "../..");
const srcDir = path.join(root, "assets", "icon", "source");
const outDir = path.join(root, "assets", "icon", "export");

const sizes = [1024, 512, 256, 192, 144, 96, 72, 48];
const names = ["app_icon_light", "app_icon_dark"];

if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

for (const base of names) {
  const svgPath = path.join(srcDir, `${base}.svg`);
  const buf = fs.readFileSync(svgPath);
  for (const s of sizes) {
    const png = await sharp(buf).resize(s, s, { fit: "fill" }).png().toBuffer();
    const out = path.join(outDir, `${base}_${s}.png`);
    fs.writeFileSync(out, png);
    console.log("wrote", path.relative(root, out));
  }
}
console.log("done");
