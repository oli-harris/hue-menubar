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

// A soft glow whose strength follows the brightness level (0-100)
export function glowSvg(colour: string, level: number): string {
  const i = Math.min(Math.max(level, 0), 100) / 100;
  const stop = (offset: number, opacity: number) =>
    `<stop offset="${offset}" stop-color="${colour}" stop-opacity="${opacity.toFixed(3)}"/>`;
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><radialGradient id="g">${stop(0, i)}${stop(0.55, i * 0.4)}${stop(1, 0)}</radialGradient></defs>` +
    `<rect width="100" height="100" rx="14" fill="#17171b"/>` +
    `<circle cx="50" cy="50" r="${(24 + 26 * i).toFixed(1)}" fill="url(#g)"/>` +
    `<circle cx="50" cy="50" r="${(5 + 9 * i).toFixed(1)}" fill="#fff" fill-opacity="${(0.55 * i).toFixed(3)}"/></svg>`
  );
}

// The average of some colours, darkened a little, as the base the glow sits on
function baseColour(colours: string[]): string {
  const sum = colours.map(hexToRgb).reduce((a, c) => [a[0] + c[0], a[1] + c[1], a[2] + c[2]], [0, 0, 0]);
  const [r, g, b] = sum.map((v) => (v / colours.length) * 0.55);
  return rgbToHex(r, g, b);
}

// A scene as a glowing light: its colours blended at the centre with a very wide blur that fills the tile
export function meshSvg(colours: string[]): string {
  const list = colours.length ? colours : [GREY];
  const blobs = list.map((c, i) => {
    const x = 75 + 28 * Math.cos(i * 2.4 + 0.6);
    const y = 50 + 18 * Math.sin(i * 2.4 + 0.6);
    return `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="42" fill="${c}"/>`;
  });
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 100"><defs><clipPath id="c"><rect width="150" height="100" rx="14"/></clipPath>` +
    `<filter id="b" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="30"/></filter></defs>` +
    `<g clip-path="url(#c)"><rect width="150" height="100" fill="${baseColour(list)}"/><g filter="url(#b)">${blobs.join("")}</g></g></svg>`
  );
}
