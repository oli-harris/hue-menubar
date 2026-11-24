import { Action, ActionPanel, Color, List, showHUD, showToast, Toast } from "@raycast/api";
import { useEffect, useRef } from "react";
import { exec, useHue } from "./hue";
import { SetupView, targetIcon } from "./targets";
import type { Target } from "./types";

// Turns a room on or off. With one room it just does it; with several you pick one.
export function RoomPower({ on }: { on: boolean }) {
  const { targets, error, isLoading, revalidate, data } = useHue();
  const started = useRef(false);
  const rooms = targets?.sections.map((s) => s.targets[0]).filter((t) => t.kind === "room") ?? [];

  const apply = async (room: Target) => {
    try {
      await exec([on ? "on" : "off", room.id]);
      await showHUD(`${room.name} ${on ? "on" : "off"}`);
    } catch (e) {
      await showToast({ style: Toast.Style.Failure, title: "Hue failed", message: (e as Error).message });
    }
  };

  const onlyRoom = rooms.length === 1 && !isLoading ? rooms[0] : undefined;
  useEffect(() => {
    if (onlyRoom && !started.current) {
      started.current = true;
      apply(onlyRoom);
    }
  });

  if (error && (error.kind !== "failed" || !data)) {
    return <SetupView kind={error.kind} message={error.message} retry={revalidate} />;
  }
  if (rooms.length <= 1) {
    return (
      <List isLoading={isLoading || rooms.length === 1}>
        <List.EmptyView title="No rooms" />
      </List>
    );
  }
  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search rooms">
      {rooms.map((room) => (
        <List.Item
          key={room.id}
          title={room.name}
          icon={targetIcon(room)}
          accessories={[
            { tag: room.isOn ? { value: "On", color: Color.Green } : { value: "Off", color: Color.SecondaryText } },
          ]}
          actions={
            <ActionPanel>
              <Action title={on ? "Turn on" : "Turn off"} onAction={() => apply(room)} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
