import { environment } from "@raycast/api";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// Writes generated SVG once, named by its content, and returns the file path to use as an image source.
// The folder and name prefix are how glow-patch/hue-glow.js finds a scene's or room's glow image.
export function svgFile(svg: string, folder = "svg", prefix = ""): string {
  const dir = join(environment.supportPath, folder);
  const file = join(dir, `${prefix}${createHash("sha1").update(svg).digest("hex").slice(0, 16)}.svg`);
  if (!existsSync(file)) {
    mkdirSync(dir, { recursive: true });
    writeFileSync(file, svg);
  }
  return file;
}
