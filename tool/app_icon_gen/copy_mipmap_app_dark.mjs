/** Android: copy app_icon_dark_*.png to res mipmap density folders as ic_launcher_dark.png */import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "../..");
const exportDir = path.join(root, "assets", "icon", "export");
const res = path.join(root, "android", "app", "src", "main", "res");

const map = [
  ["mipmap-mdpi", 48],
  ["mipmap-hdpi", 72],
  ["mipmap-xhdpi", 96],
  ["mipmap-xxhdpi", 144],
  ["mipmap-xxxhdpi", 192],
];

for (const [folder, size] of map) {
  const src = path.join(exportDir, `app_icon_dark_${size}.png`);
  if (!fs.existsSync(src)) {
    console.error("missing", src);
    process.exit(1);
  }
  const dest = path.join(res, folder, "ic_launcher_dark.png");
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(src, dest);
  console.log("wrote", path.relative(root, dest));
}
