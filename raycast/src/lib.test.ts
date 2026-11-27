import assert from "node:assert/strict";
import { test } from "node:test";
import {
  buildTargets,
  hsvToHex,
  parseColourQuery,
  parsePercent,
  exactColour,
  dimColour,
  colourName,
  saturationPercent,
  stepBrightness,
} from "./lib";
import type { HueLight, HueRoom } from "./types";

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

test("exactColour turns off contrast adjustment", () => {
  assert.deepEqual(exactColour("#ffb3b3"), { light: "#ffb3b3", dark: "#ffb3b3", adjustContrast: false });
});

test("saturationPercent", () => {
  assert.equal(saturationPercent("#ffffff"), 0);
  assert.equal(saturationPercent("#ff0000"), 100);
  assert.equal(saturationPercent(hsvToHex(0, 0.25, 1)), 25);
});

test("colourName uses plain hue names, even for pale tints", () => {
  const names = [0, 30, 55, 120, 175, 215, 270, 320].map((h) => colourName(hsvToHex(h, 1, 1)));
  assert.deepEqual(names, ["Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink"]);
  assert.equal(colourName(hsvToHex(215, 0.25, 1)), "Blue");
  assert.equal(colourName(hsvToHex(330, 0.5, 1)), "Pink");
  assert.equal(colourName(hsvToHex(350, 1, 1)), "Red");
  assert.equal(colourName("#ffffff"), "White");
  assert.equal(colourName("#808080"), "Grey");
  assert.equal(colourName("#404040"), "Grey");
});

test("stepBrightness steps by 10 and clamps", () => {
  assert.equal(stepBrightness(50, true, 1), 60);
  assert.equal(stepBrightness(95, true, 1), 100);
  assert.equal(stepBrightness(100, true, 1), 100);
  assert.equal(stepBrightness(5, true, -1), 0);
  assert.equal(stepBrightness(40, false, 1), 10); // Up from off starts at 10%
  assert.equal(stepBrightness(40, false, -1), 0);
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

test("dimmed colour darkens with brightness and greys out at 0", () => {
  assert.equal(dimColour("#ff8800", 100), "#ff8800");
  assert.equal(dimColour("#ff8800", 0), "#3a3a3c");
  const [lo, hi] = [dimColour("#ff8800", 10), dimColour("#ff8800", 60)];
  assert.ok(parseInt(lo.slice(1, 3), 16) < parseInt(hi.slice(1, 3), 16));
});
