import { Action, ActionPanel, Icon, List, environment } from "@raycast/api";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { useState } from "react";
import { run, useHue, useTarget } from "./hue";
import { previewFileName, previewSvg } from "./lib";
import type { HueScene } from "./types";

// Written once per distinct set of colours and then reused
function previewPath(colours: string[]): string {
  const dir = join(environment.supportPath, "previews");
  const file = join(dir, previewFileName(colours));
  if (!existsSync(file)) {
    mkdirSync(dir, { recursive: true });
    writeFileSync(file, previewSvg(colours));
  }
  return file;
}

// Scenes of a room. On a light target only that light's part of the scene is applied.
export function SceneList({ targetId }: { targetId: string }) {
  const target = useTarget(targetId);
  const { revalidate } = useHue();
  const [showHidden, setShowHidden] = useState(false);
  const room = target?.room;

  if (!target || !room) {
    return (
      <List>
        <List.EmptyView icon={Icon.LightBulbOff} title="Not in a room" description="Only rooms have scenes." />
      </List>
    );
  }

  const item = (scene: HueScene) => {
    const file = previewPath(scene.colours);
    const active = scene.id === room.activeSceneID;
    return (
      <List.Item
        key={scene.id}
        title={scene.name}
        icon={{ source: file }}
        accessories={active ? [{ icon: Icon.Checkmark, tooltip: "Active" }] : []}
        detail={
          <List.Item.Detail
            markdown={`![](${pathToFileURL(file).href}?raycast-width=200&raycast-height=200)\n\n# ${scene.name}${active ? "\n\nActive" : ""}`}
          />
        }
        actions={
          <ActionPanel>
            <Action
              title="Apply Scene"
              icon={Icon.Wand}
              onAction={() => run(["scene", target.id, scene.id], `${scene.name} applied`, revalidate)}
            />
            {room.disabledScenes.length > 0 && (
              <Action
                title={showHidden ? "Hide Hidden Scenes" : "Show Hidden Scenes"}
                icon={showHidden ? Icon.EyeDisabled : Icon.Eye}
                shortcut={{ modifiers: ["cmd"], key: "h" }}
                onAction={() => setShowHidden(!showHidden)}
              />
            )}
          </ActionPanel>
        }
      />
    );
  };

  return (
    <List isShowingDetail navigationTitle={`${target.name} Scenes`} searchBarPlaceholder="Search scenes">
      <List.Section title={room.name}>{room.scenes.map(item)}</List.Section>
      {showHidden && <List.Section title="Hidden">{room.disabledScenes.map(item)}</List.Section>}
    </List>
  );
}
