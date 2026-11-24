import assert from "node:assert/strict";
import { test } from "node:test";
import {
  brightnessTint,
  buildTargets,
  hsvToHex,
  parseColourQuery,
  parsePercent,
  previewFileName,
  previewSvg,
} from "./lib";
import type { HueLight, HueRoom } from "./types";

test("brightnessTint darkens but keeps a floor", () => {
  assert.equal(brightnessTint("#ff8000", 100), "#ff8000");
  assert.equal(brightnessTint("#ffffff", 0), "#404040");
  assert.equal(brightnessTint("#ffffff", 50), "#9f9f9f");
});

test("hsvToHex", () => {
  assert.equal(hsvToHex(0, 1, 1), "#ff0000");
  assert.equal(hsvToHex(120, 1, 1), "#00ff00");
  assert.equal(hsvToHex(240, 0.5, 1), "#8080ff");
});

test("parseColourQuery accepts hex and CSS names", () => {
  assert.deepEqual(parseColourQuery("#F00"), { hex: "#ff0000", label: "#ff0000" });
  assert.deepEqual(parseColourQuery("00ff80"), { hex: "#00ff80", label: "#00ff80" });
  assert.deepEqual(parseColourQuery("Tomato"), { hex: "#ff6347", label: "tomato" });
  for (const bad of ["", "#12", "#ggg", "tomatoe", "#1234567"]) assert.equal(parseColourQuery(bad), undefined);
});

test("parsePercent", () => {
  assert.equal(parsePercent("40"), 40);
  assert.equal(parsePercent("100%"), 100);
  for (const bad of ["101", "-1", "abc", "", "4.5"]) assert.equal(parsePercent(bad), undefined);
});

test("previewSvg is stable and keyed by colours", () => {
  assert.equal(previewSvg(["#ff0000", "#0000ff"]).match(/<rect x/g)?.length, 2);
  assert.equal(previewFileName(["#ff0000"]), previewFileName(["#ff0000"]));
  assert.notEqual(previewFileName(["#ff0000"]), previewFileName(["#00ff00"]));
  assert.match(previewSvg([]), /#6b6b6b/);
});

test("buildTargets lists rooms, their lights, then unassigned lights", () => {
  const light = (id: string, isOn: boolean, colour: string): HueLight => ({
    id,
    name: id,
    bridgeName: id,
    isOn,
    colour,
    supportsColor: id === "l2",
    supportsTemperature: true,
  });
  const room: HueRoom = {
    id: "r1",
    name: "Room",
    bridgeName: "Room",
    isOn: true,
    lights: [light("l1", false, "#111111"), light("l2", true, "#222222")],
    scenes: [],
    disabledScenes: [],
  };
  const { all, sections } = buildTargets({ rooms: [room], unassigned: [light("l3", true, "#333333")] });
  assert.deepEqual(
    sections.map((s) => s.targets.map((t) => t.id)),
    [["r1", "l1", "l2"], ["l3"]],
  );
  assert.equal(sections[0].targets[0].colour, "#222222"); // First light that is on
  assert.equal(sections[0].targets[0].supportsColor, true);
  assert.equal(sections[0].targets[1].supportsColor, false);
  assert.equal(all.id, "all");
});
