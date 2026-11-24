import { Action, Icon, type Keyboard } from "@raycast/api";
import type { ReactElement } from "react";
import { BrightnessGrid } from "./brightness-grid";
import { ColourGrid } from "./colour-grid";
import { run } from "./hue";
import { stepBrightness } from "./lib";
import { SceneList } from "./scene-list";
import type { Target } from "./types";

export interface TargetAction {
  key: string;
  title: string;
  icon: Icon;
  label: string; // The shortcut as shown in menus
  element: ReactElement;
}

const shortcut = (key: Keyboard.KeyEquivalent): Keyboard.Shortcut => ({ modifiers: ["cmd", "shift"], key });
const GLYPHS: Record<string, string> = { return: "↩", delete: "⌫", arrowUp: "↑", arrowDown: "↓" };
const label = (key: string) => `⌘⇧${GLYPHS[key] ?? key.toUpperCase()}`;

// Everything a user can do to a target, in menu order, with the same shortcuts everywhere
export function targetActions(target: Target, revalidate: () => void): TargetAction[] {
  const push = (key: string, title: string, icon: Icon, k: Keyboard.KeyEquivalent, page: ReactElement) => ({
    key,
    title,
    icon,
    label: label(k),
    element: <Action.Push key={key} title={title} icon={icon} shortcut={shortcut(k)} target={page} />,
  });
  const make = (key: string, title: string, icon: Icon, k: Keyboard.KeyEquivalent, args: string[], done: string) => ({
    key,
    title,
    icon,
    label: label(k),
    element: (
      <Action key={key} title={title} icon={icon} shortcut={shortcut(k)} onAction={() => run(args, done, revalidate)} />
    ),
  });
  const step = (direction: 1 | -1) => {
    const level = stepBrightness(target.brightness, target.isOn, direction);
    return make(
      direction === 1 ? "up" : "down",
      direction === 1 ? "Brightness up" : "Brightness down",
      direction === 1 ? Icon.ArrowUp : Icon.ArrowDown,
      direction === 1 ? "arrowUp" : "arrowDown",
      ["brightness", target.id, String(level)],
      `${target.name} at ${level}%`,
    );
  };
  return [
    push("colour", "Colour", Icon.Brush, "c", <ColourGrid targetId={target.id} />),
    push("brightness", "Brightness", Icon.LightBulb, "b", <BrightnessGrid targetId={target.id} />),
    ...(target.room ? [push("scene", "Scene", Icon.Wand, "s", <SceneList targetId={target.id} />)] : []),
    make("on", "On", Icon.Power, "return", ["on", target.id], `${target.name} on`),
    make("off", "Off", Icon.LightBulbOff, "delete", ["off", target.id], `${target.name} off`),
    step(1),
    step(-1),
  ];
}
