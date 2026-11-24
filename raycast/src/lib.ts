import { createHash } from "node:crypto";
import { CSS_COLOURS } from "./css-colours";
import type { HueData, HueLight, HueRoom, Target } from "./types";

export const WHITES = [
  { name: "Candle", kelvin: 2000, hex: "#ff890e" },
  { name: "Warm", kelvin: 2700, hex: "#ffa757" },
  { name: "Neutral", kelvin: 4000, hex: "#ffcea6" },
  { name: "Cool", kelvin: 5000, hex: "#ffe4ce" },
  { name: "Daylight", kelvin: 6500, hex: "#fffefa" },
];

export function hexToRgb(hex: string): [number, number, number] {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

export function rgbToHex(r: number, g: number, b: number): string {
  return (
    "#" +
    [r, g, b]
      .map((c) =>
        Math.round(Math.min(Math.max(c, 0), 255))
          .toString(16)
          .padStart(2, "0"),
      )
      .join("")
  );
}

export function hsvToHex(h: number, s: number, v: number): string {
  const f = (n: number) => {
    const k = (n + h / 60) % 6;
    return v - v * s * Math.max(Math.min(k, 4 - k, 1), 0);
  };
  return rgbToHex(f(5) * 255, f(3) * 255, f(1) * 255);
}

// "#rgb", "#rrggbb" (the # optional) or a CSS colour name
export function parseColourQuery(text: string): { hex: string; label: string } | undefined {
  const s = text.trim().toLowerCase();
  const name = CSS_COLOURS[s];
  if (name) return { hex: name, label: s };
  const m = /^#?([0-9a-f]{3}|[0-9a-f]{6})$/.exec(s);
  if (!m) return undefined;
  const digits = m[1].length === 3 ? [...m[1]].map((c) => c + c).join("") : m[1];
  return { hex: "#" + digits, label: "#" + digits };
}

// "40" or "40%", 0-100
export function parsePercent(text: string): number | undefined {
  const m = /^(\d{1,3})\s*%?$/.exec(text.trim());
  return m && Number(m[1]) <= 100 ? Number(m[1]) : undefined;
}

// A room shows the colour of its first light that is on
export function groupColour(lights: HueLight[]): string | undefined {
  return (lights.find((l) => l.isOn && l.colour) ?? lights.find((l) => l.colour))?.colour;
}

export function buildTargets({ rooms, unassigned }: HueData): {
  all: Target;
  sections: { title: string; targets: Target[] }[];
} {
  const lightTarget = (light: HueLight, room?: HueRoom): Target => ({
    id: light.id,
    kind: "light",
    name: light.name,
    type: light.type,
    room,
    isOn: light.isOn,
    brightness: light.brightness,
    colour: light.colour,
    supportsColor: light.supportsColor,
  });
  const lights = [...rooms.flatMap((r) => r.lights), ...unassigned];
  const sections = rooms.map((room) => ({
    title: room.name,
    targets: [
      {
        id: room.id,
        kind: "room" as const,
        name: room.name,
        type: room.type,
        room,
        isOn: room.isOn,
        brightness: room.brightness,
        colour: groupColour(room.lights),
        supportsColor: room.lights.some((l) => l.supportsColor),
      },
      ...room.lights.map((l) => lightTarget(l, room)),
    ],
  }));
  if (unassigned.length) sections.push({ title: "Other Lights", targets: unassigned.map((l) => lightTarget(l)) });
  return {
    all: {
      id: "all",
      kind: "all",
      name: "All Lights",
      isOn: lights.some((l) => l.isOn),
      colour: groupColour(lights),
      supportsColor: lights.some((l) => l.supportsColor),
    },
    sections,
  };
}

// Raycast shifts colours for contrast with its theme unless told not to, which ruins swatches and tints
export function exactColour(hex: string) {
  return { light: hex, dark: hex, adjustContrast: false };
}

// HSV saturation as a whole percent: 0 for white and greys, 100 for a pure colour
export function saturationPercent(hex: string): number {
  const [r, g, b] = hexToRgb(hex);
  const max = Math.max(r, g, b);
  return max === 0 ? 0 : Math.round(((max - Math.min(r, g, b)) / max) * 100);
}

export function nearestColourName(hex: string): string {
  const [r, g, b] = hexToRgb(hex);
  let best = "";
  let bestDistance = Infinity;
  for (const [name, value] of Object.entries(CSS_COLOURS)) {
    const [r2, g2, b2] = hexToRgb(value);
    const d = (r - r2) ** 2 + (g - g2) ** 2 + (b - b2) ** 2;
    if (d < bestDistance) [best, bestDistance] = [name, d];
  }
  return best;
}

// Next brightness one step (10%) up or down; up from off starts at 10%, 0 means off
export function stepBrightness(brightness: number | undefined, isOn: boolean, direction: 1 | -1): number {
  const current = isOn ? Math.round(brightness ?? 100) : 0;
  return Math.min(Math.max(current + direction * 10, 0), 100);
}

// Stripes of a scene's colours, a neutral grey when it has none
export function previewSvg(colours: string[]): string {
  const list = colours.length ? colours : ["#6b6b6b"];
  const width = 100 / list.length;
  const stripes = list
    .map((c, i) => `<rect x="${i * width}" y="0" width="${width + 0.5}" height="100" fill="${c}"/>`)
    .join("");
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><clipPath id="c"><rect width="100" height="100" rx="18"/></clipPath><g clip-path="url(#c)">${stripes}</g></svg>`;
}

export function previewFileName(colours: string[]): string {
  return `scene-${createHash("sha1").update(colours.join(",")).digest("hex").slice(0, 12)}.svg`;
}
