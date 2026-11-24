// Small original icons and generated tiles, as SVG strings. Pure, so they can be tested.
export const GREY = "#8a8a8a";

export type LightFamily = "bulb" | "candle" | "spot" | "strip" | "floor" | "table" | "ceiling" | "orb";
export type RoomFamily = "bed" | "sofa" | "kitchen" | "dining" | "bath" | "desk" | "door" | "house";

// The bridge's archetype names, matched loosely so new ones still land somewhere sensible
const LIGHT_FAMILIES: [RegExp, LightFamily][] = [
  [/lightstrip|omniglow|gradient|play|tube|string|neon/, "strip"],
  [/floor|signe|lantern/, "floor"],
  [/table|flexible|wash/, "table"],
  [/ceiling|pendant|centris/, "ceiling"],
  [/spot|flood|recessed|ground|bollard/, "spot"],
  [/candle|luster/, "candle"],
  [/hue_go|iris|bloom|globe|ellipse|plug/, "orb"],
];

const ROOM_FAMILIES: [RegExp, RoomFamily][] = [
  [/bedroom|nursery|guest/, "bed"],
  [/living|lounge|^tv|recreation|man_cave|reading|music/, "sofa"],
  [/kitchen/, "kitchen"],
  [/dining/, "dining"],
  [/bath|toilet|laundry|pool/, "bath"],
  [/office|computer|studio|gym/, "desk"],
  [/hall|stair|door|downstairs|upstairs|top_floor|garage|porch/, "door"],
];

export function lightFamily(type?: string): LightFamily {
  return LIGHT_FAMILIES.find(([re]) => re.test(type ?? ""))?.[1] ?? "bulb";
}

export function roomFamily(type?: string): RoomFamily {
  return ROOM_FAMILIES.find(([re]) => re.test(type ?? ""))?.[1] ?? "house";
}

const DETAIL = `fill="#000" fill-opacity=".3" stroke="none"`;

const LIGHT_SHAPES: Record<LightFamily, string> = {
  bulb: `<circle cx="32" cy="26" r="16"/><rect x="25" y="41" width="14" height="8" rx="2"/><rect x="27" y="51" width="10" height="5" rx="2.5" ${DETAIL}/>`,
  candle: `<path d="M32 6C43 20 45 30 39 38Q32 43 25 38C19 30 21 20 32 6Z"/><rect x="26" y="42" width="12" height="8" rx="2"/><rect x="28" y="52" width="8" height="5" rx="2.5" ${DETAIL}/>`,
  spot: `<rect x="23" y="6" width="18" height="10" rx="3" ${DETAIL}/><polygon points="22,16 42,16 54,48 10,48"/>`,
  strip: `<rect x="5" y="24" width="54" height="16" rx="8"/><circle cx="18" cy="32" r="2.5" ${DETAIL}/><circle cx="32" cy="32" r="2.5" ${DETAIL}/><circle cx="46" cy="32" r="2.5" ${DETAIL}/>`,
  floor: `<polygon points="22,6 42,6 49,26 15,26"/><rect x="30" y="26" width="4" height="26" ${DETAIL}/><rect x="19" y="52" width="26" height="5" rx="2.5" ${DETAIL}/>`,
  table: `<polygon points="21,8 43,8 51,30 13,30"/><rect x="29" y="30" width="6" height="14" ${DETAIL}/><rect x="20" y="44" width="24" height="8" rx="4" ${DETAIL}/>`,
  ceiling: `<rect x="31" y="4" width="2" height="14" ${DETAIL}/><path d="M12 42Q12 18 32 18Q52 18 52 42Z"/><rect x="12" y="42" width="40" height="4" rx="2" ${DETAIL}/>`,
  orb: `<circle cx="32" cy="30" r="20"/><circle cx="32" cy="30" r="12" fill="#fff" fill-opacity=".25" stroke="none"/><rect x="20" y="52" width="24" height="5" rx="2.5" ${DETAIL}/>`,
};

const ROOM_SHAPES: Record<RoomFamily, string> = {
  bed: `<rect x="6" y="38" width="52" height="12" rx="3"/><rect x="6" y="22" width="7" height="28" rx="3"/><rect x="16" y="28" width="16" height="9" rx="4" ${DETAIL}/>`,
  sofa: `<rect x="12" y="20" width="40" height="18" rx="7"/><rect x="5" y="28" width="12" height="20" rx="5"/><rect x="47" y="28" width="12" height="20" rx="5"/><rect x="12" y="34" width="40" height="14" rx="5"/>`,
  kitchen: `<rect x="14" y="28" width="36" height="22" rx="5"/><rect x="11" y="23" width="42" height="6" rx="3" ${DETAIL}/><rect x="5" y="33" width="9" height="4" rx="2"/><rect x="50" y="33" width="9" height="4" rx="2"/>`,
  dining: `<rect x="7" y="28" width="50" height="7" rx="3"/><rect x="13" y="35" width="6" height="17" rx="2"/><rect x="45" y="35" width="6" height="17" rx="2"/><circle cx="32" cy="22" r="5" ${DETAIL}/>`,
  bath: `<path d="M7 30H57V36Q57 50 43 50H21Q7 50 7 36Z"/><rect x="5" y="26" width="54" height="5" rx="2.5" ${DETAIL}/><rect x="14" y="50" width="5" height="6" ${DETAIL}/><rect x="45" y="50" width="5" height="6" ${DETAIL}/>`,
  desk: `<rect x="12" y="10" width="40" height="28" rx="4"/><rect x="28" y="38" width="8" height="10" ${DETAIL}/><rect x="20" y="48" width="24" height="5" rx="2.5" ${DETAIL}/>`,
  door: `<rect x="16" y="6" width="32" height="52" rx="4"/><circle cx="41" cy="34" r="2.5" ${DETAIL}/>`,
  house: `<path d="M6 32L32 9L58 32H51V54H13V32Z"/><rect x="27" y="38" width="10" height="16" rx="2" ${DETAIL}/>`,
};

function icon(shapes: string, colour: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><g fill="${colour}" stroke="#808080" stroke-opacity=".6" stroke-width="1.5">${shapes}</g></svg>`;
}

export function lightIconSvg(type: string | undefined, colour: string): string {
  return icon(LIGHT_SHAPES[lightFamily(type)], colour);
}

export function roomIconSvg(type: string | undefined, colour: string): string {
  return icon(ROOM_SHAPES[roomFamily(type)], colour);
}

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

// A blurred blend of a scene's colours, like a mesh gradient
export function meshSvg(colours: string[]): string {
  const list = colours.length ? colours : [GREY];
  const blobs = list.map((c, i) => {
    const x = 75 + 48 * Math.cos(i * 2.4);
    const y = 50 + 30 * Math.sin(i * 2.4);
    return (
      `<radialGradient id="r${i}"><stop offset="0" stop-color="${c}"/><stop offset="1" stop-color="${c}" stop-opacity="0"/></radialGradient>` +
      `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="60" fill="url(#r${i})"/>`
    );
  });
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 100"><defs><clipPath id="c"><rect width="150" height="100" rx="14"/></clipPath>` +
    `<filter id="b" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="14"/></filter></defs>` +
    `<g clip-path="url(#c)"><rect width="150" height="100" fill="${list[0]}"/><g filter="url(#b)">${blobs.join("")}</g></g></svg>`
  );
}
