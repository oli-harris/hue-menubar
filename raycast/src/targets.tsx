import { Action, ActionPanel, Color, Icon, List, openExtensionPreferences } from "@raycast/api";
import { execFile } from "node:child_process";
import type { ReactElement } from "react";
import { SceneList } from "./scene-list";
import { APP_BUNDLE_ID, run, useHue, useTarget } from "./hue";
import type { Target } from "./types";

// Everything a user can do to a target, in menu order
function targetActions(target: Target, revalidate: () => void) {
  const make = (key: string, title: string, icon: Icon, onAction: () => void) => ({
    key,
    title,
    icon,
    element: <Action key={key} title={title} icon={icon} onAction={onAction} />,
  });
  const push = (key: string, title: string, icon: Icon, page: ReactElement) => ({
    key,
    title,
    icon,
    element: <Action.Push key={key} title={title} icon={icon} target={page} />,
  });
  return [
    ...(target.kind === "all" ? [] : [push("scene", "Set scene", Icon.Wand, <SceneList targetId={target.id} />)]),
    make("on", "Turn on", Icon.LightBulb, () => run(["on", target.id], `${target.name} on`, revalidate)),
    make("off", "Turn off", Icon.LightBulbOff, () => run(["off", target.id], `${target.name} off`, revalidate)),
  ];
}

function targetIcon(t: Target) {
  return { source: Icon.LightBulb, tintColor: t.isOn ? (t.colour ?? Color.Yellow) : Color.SecondaryText };
}

function SetupView({ kind, message, retry }: { kind: string; message: string; retry: () => void }) {
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

// The first screen of every command: rooms with their lights, optionally "All Lights" on top.
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

  const item = (t: Target, subtitle?: string) => (
    <List.Item
      key={t.id}
      id={t.id}
      title={t.name}
      subtitle={subtitle ?? (t.kind === "room" ? "Room" : undefined)}
      icon={targetIcon(t)}
      keywords={[t.room?.name ?? ""]}
      accessories={[
        { tag: t.isOn ? { value: "On", color: Color.Green } : { value: "Off", color: Color.SecondaryText } },
        ...(t.isOn && t.brightness !== undefined ? [{ text: `${Math.round(t.brightness)}%` }] : []),
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
      {props.includeAll && targets && <List.Section>{item(targets.all)}</List.Section>}
      {targets?.sections.map((s) => (
        <List.Section key={s.title} title={s.title}>
          {s.targets.map((t) => item(t, t.kind === "light" ? t.room?.name : undefined))}
        </List.Section>
      ))}
    </List>
  );
}

// Enter on a target in the Lights command: choose what to do with it
export function TargetMenu({ targetId }: { targetId: string }) {
  const target = useTarget(targetId);
  const { revalidate } = useHue();
  if (!target) return <List />;
  return (
    <List navigationTitle={target.name}>
      {targetActions(target, revalidate).map((a) => (
        <List.Item key={a.key} title={a.title} icon={a.icon} actions={<ActionPanel>{a.element}</ActionPanel>} />
      ))}
    </List>
  );
}
