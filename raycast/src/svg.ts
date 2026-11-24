// Generated images as SVG strings: tinted Hue icons, a brightness glow and a scene glow. Pure, so testable.
import { HUE_ICON_PATHS, LIGHT_ICONS, ROOM_ICONS } from "../assets/hue-icons/icons";
import { hexToRgb, rgbToHex } from "./lib";

export const GREY = "#8a8a8a";

export function lightIconName(type?: string): string {
  return LIGHT_ICONS[type ?? ""] ?? "bulb-classic";
}

export function roomIconName(type?: string): string {
  return ROOM_ICONS[type ?? ""] ?? "room-other";
}

// An icon filled with the light's colour, outlined faintly so pale colours stay visible on any theme
export function iconSvg(name: string, colour: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="${HUE_ICON_PATHS[name]}" fill="${colour}" stroke="#808080" stroke-opacity=".5" stroke-width=".5"/></svg>`;
}

export const lightIconSvg = (type: string | undefined, colour: string) => iconSvg(lightIconName(type), colour);
export const roomIconSvg = (type: string | undefined, colour: string) => iconSvg(roomIconName(type), colour);

// The average of some colours: the base that fills the whole tile, so no edge fades out
function baseColour(colours: string[]): string {
  const sum = colours.map(hexToRgb).reduce((a, c) => [a[0] + c[0], a[1] + c[1], a[2] + c[2]], [0, 0, 0]);
  const [r, g, b] = sum.map((v) => v / colours.length);
  return rgbToHex(r, g, b);
}

// A scene as a glowing light: its colours blended at the centre with a very wide blur that fills the tile
export function meshSvg(colours: string[]): string {
  const list = colours.length ? colours : [GREY];
  const blobs = list.map((c, i) => {
    const x = 75 + 28 * Math.cos(i * 2.4 + 0.6);
    const y = 50 + 18 * Math.sin(i * 2.4 + 0.6);
    return `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="50" fill="${c}"/>`;
  });
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 100"><defs><clipPath id="c"><rect width="150" height="100" rx="14"/></clipPath>` +
    `<filter id="b" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="26" edgeMode="duplicate"/></filter></defs>` +
    `<g clip-path="url(#c)"><rect width="150" height="100" fill="${baseColour(list)}"/><g filter="url(#b)">${blobs.join("")}</g></g></svg>`
  );
}
