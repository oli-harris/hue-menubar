import assert from "node:assert/strict";
import { test } from "node:test";
import { HUE_ICON_PATHS, LIGHT_ICONS, ROOM_ICONS } from "../assets/hue-icons/icons";
import { lightIconName, lightIconSvg, meshSvg, roomIconName, roomIconSvg } from "./svg";

test("archetypes map to icons, with fallbacks", () => {
  const lights: [string | undefined, string][] = [
    ["sultan_bulb", "bulb-sultan"],
    ["candle_bulb", "bulb-candle"],
    ["hue_lightstrip", "lightstrip"],
    ["hue_omniglow", "lightstrip-wrap"],
    ["floor_shade", "floor-shade"],
    ["table_wash", "table-wash"],
    ["hue_bloom", "bloom"],
    ["pendant_round", "pendant-round"],
    [undefined, "bulb-classic"],
    ["something_new", "bulb-classic"],
  ];
  for (const [type, icon] of lights) assert.equal(lightIconName(type), icon, String(type));
  const rooms: [string | undefined, string][] = [
    ["bedroom", "room-bedroom"],
    ["living_room", "room-living"],
    ["kitchen", "room-kitchen"],
    ["other", "room-other"],
    [undefined, "room-other"],
  ];
  for (const [type, icon] of rooms) assert.equal(roomIconName(type), icon, String(type));
});

test("every mapped icon has path data", () => {
  for (const name of [...Object.values(LIGHT_ICONS), ...Object.values(ROOM_ICONS)]) {
    assert.ok(HUE_ICON_PATHS[name]?.length > 10, name);
  }
});

function assertSvg(svg: string) {
  assert.match(svg, /^<svg xmlns="http:\/\/www\.w3\.org\/2000\/svg" viewBox="[\d. ]+">/);
  assert.ok(svg.endsWith("</svg>"));
  assert.ok(!svg.includes("undefined") && !svg.includes("NaN"));
  // Every opened tag is self-closed or closed
  const opens = (svg.match(/<(?!\/)[a-zA-Z]+[^>]*[^/]>/g) ?? []).length;
  const closes = (svg.match(/<\/[a-zA-Z]+>/g) ?? []).length;
  assert.equal(opens, closes);
}

test("generated SVGs are well formed", () => {
  for (const type of [
    "sultan_bulb",
    "candle_bulb",
    "spot_bulb",
    "hue_lightstrip",
    "floor_shade",
    "table_shade",
    "pendant_round",
    "hue_bloom",
    undefined,
  ]) {
    const svg = lightIconSvg(type, "#ff8800");
    assertSvg(svg);
    assert.ok(svg.includes("#ff8800"));
  }
  for (const type of ["bedroom", "living_room", "kitchen", "dining", "bathroom", "office", "hallway", "other"])
    assertSvg(roomIconSvg(type, "#8a8a8a"));
  assertSvg(meshSvg(["#ff0000", "#00ff00", "#0000ff"]));
  assertSvg(meshSvg([]));
});

test("mesh is based on the average colour, filling the tile", () => {
  const svg = meshSvg(["#ff0000", "#0000ff"]);
  assert.ok(svg.includes('<rect width="150" height="100" fill="#800080"/>'));
  assert.ok(svg.includes('edgeMode="duplicate"'));
});

test("mesh uses every colour", () => {
  const svg = meshSvg(["#ff0000", "#00ff00", "#0000ff"]);
  for (const c of ["#ff0000", "#00ff00", "#0000ff"]) assert.ok(svg.includes(c));
});
