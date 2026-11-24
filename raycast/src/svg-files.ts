import { environment } from "@raycast/api";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// Writes generated SVG once, named by its content, and returns the file path to use as an image source
export function svgFile(svg: string): string {
  const dir = join(environment.supportPath, "svg");
  const file = join(dir, `${createHash("sha1").update(svg).digest("hex").slice(0, 16)}.svg`);
  if (!existsSync(file)) {
    mkdirSync(dir, { recursive: true });
    writeFileSync(file, svg);
  }
  return file;
}
