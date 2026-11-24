import assert from "node:assert/strict";
import { test } from "node:test";
import { glowSvg, lightFamily, lightIconSvg, meshSvg, roomFamily, roomIconSvg } from "./svg";

test("archetypes map to icon families", () => {
  const cases: [string | undefined, string][] = [
    ["sultan_bulb", "bulb"],
    ["classic_bulb", "bulb"],
    ["candle_bulb", "candle"],
    ["spot_bulb", "spot"],
    ["hue_lightstrip", "strip"],
    ["hue_omniglow", "strip"],
    ["floor_shade", "floor"],
    ["floor_lantern", "floor"],
    ["table_shade", "table"],
    ["table_wash", "table"],
    ["pendant_round", "ceiling"],
    ["ceiling_round", "ceiling"],
    ["hue_bloom", "orb"],
    ["hue_go", "orb"],
    ["hue_iris", "orb"],
    [undefined, "bulb"],
    ["something_new", "bulb"],
  ];
  for (const [type, family] of cases) assert.equal(lightFamily(type), family, String(type));
  const rooms: [string | undefined, string][] = [
    ["bedroom", "bed"],
    ["living_room", "sofa"],
    ["kitchen", "kitchen"],
    ["bathroom", "bath"],
    ["office", "desk"],
    ["dining", "dining"],
    ["hallway", "door"],
    ["other", "house"],
    [undefined, "house"],
  ];
  for (const [type, family] of rooms) assert.equal(roomFamily(type), family, String(type));
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
  for (const level of [0, 10, 50, 100]) assertSvg(glowSvg("#ffcc00", level));
  assertSvg(meshSvg(["#ff0000", "#00ff00", "#0000ff"]));
  assertSvg(meshSvg([]));
});

test("glow intensity follows brightness", () => {
  const opacity = (svg: string) => Number(/offset="0" stop-color="#ffcc00" stop-opacity="([\d.]+)"/.exec(svg)?.[1]);
  assert.equal(opacity(glowSvg("#ffcc00", 0)), 0);
  assert.ok(opacity(glowSvg("#ffcc00", 50)) < opacity(glowSvg("#ffcc00", 100)));
  assert.equal(opacity(glowSvg("#ffcc00", 100)), 1);
});

test("mesh uses every colour", () => {
  const svg = meshSvg(["#ff0000", "#00ff00", "#0000ff"]);
  for (const c of ["#ff0000", "#00ff00", "#0000ff"]) assert.ok(svg.includes(c));
});
