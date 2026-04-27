/**
 * @deprecated Replaced by copy_mipmap_app_dark.mjs + activity-alias (in-app theme, not system night).
 */
import fs from "fs";
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
  const nightFolder = path.join(res, folder.replace("mipmap-", "mipmap-night-"));
  const src = path.join(exportDir, `app_icon_dark_${size}.png`);
  if (!fs.existsSync(src)) {
    console.error("missing", src);
    process.exit(1);
  }
  fs.mkdirSync(nightFolder, { recursive: true });
  const dest = path.join(nightFolder, "ic_launcher.png");
  fs.copyFileSync(src, dest);
  console.log("wrote", path.relative(root, dest));
}
