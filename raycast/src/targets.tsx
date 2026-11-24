import { Action, ActionPanel, Color, Icon, List, openExtensionPreferences } from "@raycast/api";
import { execFile } from "node:child_process";
import type { ReactElement } from "react";
import { targetActions } from "./actions";
import { basename } from "node:path";
import { APP_BUNDLE_ID, useHue, useTarget } from "./hue";
import { GREY, lightIconSvg, meshSvg, roomIconSvg } from "./svg";
import { svgFile } from "./svg-files";
import type { Target } from "./types";

// The room's lit colours as a glow image. Icons of the room and its lights are named
// "<glow name>~<hash>.svg" so the Raycast glow patch can find the room's glow from any row.
function roomGlowPrefix(t: Target): string {
  const lights = t.kind === "all" ? t.lights : t.room?.lights;
  const colours = lights?.filter((l) => l.isOn && l.colour).map((l) => l.colour as string) ?? [];
  if (colours.length === 0) return "";
  const id = t.kind === "all" ? "all" : t.room?.id;
  return `${basename(svgFile(meshSvg(colours), "room-glow", `${id}~`), ".svg")}~`;
}

export function targetIcon(t: Target) {
  const colour = t.isOn && t.colour ? t.colour : GREY; // Grey until the colour is known
  const svg = t.kind === "light" ? lightIconSvg(t.type, colour) : roomIconSvg(t.type, colour);
  return { source: svgFile(svg, "svg", roomGlowPrefix(t)) };
}

export function SetupView({ kind, message, retry }: { kind: string; message: string; retry: () => void }) {
  return (
    <List>
      <List.EmptyView
        icon={Icon.LightBulbOff}
        title={
          kind === "unpaired"
            ? "Pair in Hue Menubar first"
            : kind === "missing"
              ? "Hue Menubar not found"
              : "Hue Menubar failed"
        }
        description={message}
        actions={
          <ActionPanel>
            {kind === "unpaired" && (
              <Action title="Open Hue Menubar" onAction={() => execFile("open", ["-b", APP_BUNDLE_ID])} />
            )}
            {kind === "missing" && <Action title="Open Extension Preferences" onAction={openExtensionPreferences} />}
            {kind === "failed" && <Action title="Retry" onAction={retry} />}
          </ActionPanel>
        }
      />
    </List>
  );
}

// The first screen of every command: a section per room, starting with the whole room, then its lights.
// `primary` is what Enter does, `withMenu` also puts every action in the action panel.
export function TargetList(props: {
  primary: (target: Target, revalidate: () => void) => ReactElement;
  includeAll?: boolean;
  withMenu?: boolean;
}) {
  const { targets, error, isLoading, revalidate, data } = useHue();
  if (error && (error.kind !== "failed" || !data)) {
    return <SetupView kind={error.kind} message={error.message} retry={revalidate} />;
  }

  const item = (t: Target, name: string) => (
    <List.Item
      key={t.id}
      id={t.id}
      title={t.isOn && t.brightness !== undefined ? `${name} · ${Math.round(t.brightness)}%` : name}
      icon={targetIcon(t)}
      keywords={[t.room?.name ?? t.name]}
      accessories={[
        { tag: t.isOn ? { value: "On", color: Color.Green } : { value: "Off", color: Color.SecondaryText } },
      ]}
      actions={
        <ActionPanel>
          {props.primary(t, revalidate)}
          {props.withMenu && (
            <ActionPanel.Section>{targetActions(t, revalidate).map((a) => a.element)}</ActionPanel.Section>
          )}
        </ActionPanel>
      }
    />
  );

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search lights and rooms">
      {props.includeAll && targets && <List.Section>{item(targets.all, targets.all.name)}</List.Section>}
      {targets?.sections.map((s) => (
        <List.Section key={s.title} title={s.title}>
          {s.targets.map((t) => item(t, t.kind === "room" ? `Entire ${t.name}` : t.name))}
        </List.Section>
      ))}
    </List>
  );
}

// Enter on a target in Control Lights: a plain list of what can be done with it
export function TargetMenu({ targetId }: { targetId: string }) {
  const { target, revalidate } = useTarget(targetId);
  if (!target) return <List />;
  const actions = targetActions(target, revalidate);
  return (
    <List navigationTitle={target.name}>
      {actions
        .filter((a) => !["up", "down"].includes(a.key))
        .map((a) => (
          <List.Item
            key={a.key}
            title={a.title}
            icon={a.icon}
            accessories={[{ text: a.label }]}
            actions={
              <ActionPanel>
                {a.element}
                {actions.filter((o) => o.key !== a.key).map((o) => o.element)}
              </ActionPanel>
            }
          />
        ))}
    </List>
  );
}
