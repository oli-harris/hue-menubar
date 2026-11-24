import { Action, ActionPanel, Color, Icon, List, openExtensionPreferences } from "@raycast/api";
import { execFile } from "node:child_process";
import type { ReactElement } from "react";
import { targetActions } from "./actions";
import { APP_BUNDLE_ID, useHue, useTarget } from "./hue";
import { GREY, lightIconSvg, roomIconSvg } from "./svg";
import { svgFile } from "./svg-files";
import type { Target } from "./types";

export function targetIcon(t: Target) {
  const colour = t.isOn ? (t.colour ?? "#ffd5b3") : GREY;
  return { source: svgFile(t.kind === "light" ? lightIconSvg(t.type, colour) : roomIconSvg(t.type, colour)) };
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

  const item = (t: Target, title: string) => (
    <List.Item
      key={t.id}
      id={t.id}
      title={title}
      icon={targetIcon(t)}
      keywords={[t.room?.name ?? t.name]}
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
  const target = useTarget(targetId);
  const { revalidate } = useHue();
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
