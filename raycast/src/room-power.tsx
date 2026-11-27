import {
  Action,
  ActionPanel,
  Color,
  Detail,
  List,
  PopToRootType,
  closeMainWindow,
  showHUD,
  showToast,
  Toast,
} from "@raycast/api";
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
      await closeMainWindow({ clearRootSearch: true, popToRootType: PopToRootType.Immediate });
      await showHUD(`${room.name} ${on ? "on" : "off"}`);
    } catch (e) {
      await showToast({ style: Toast.Style.Failure, title: "Hue failed", message: (e as Error).message });
    }
  };

  // Cached data is enough to act on: the room ids don't change
  const onlyRoom = rooms.length === 1 ? rooms[0] : undefined;
  useEffect(() => {
    if (onlyRoom && !started.current) {
      started.current = true;
      apply(onlyRoom);
    }
  });

  if (error && (error.kind !== "failed" || !data)) {
    return <SetupView kind={error.kind} message={error.message} retry={revalidate} />;
  }
  // One room is acted on straight away, so show nothing meanwhile
  if (rooms.length === 1) return <Detail markdown="" />;
  if (rooms.length === 0) {
    return (
      <List isLoading={isLoading}>
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
