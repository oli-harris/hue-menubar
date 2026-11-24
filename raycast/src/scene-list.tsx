import { Action, ActionPanel, Grid, Icon } from "@raycast/api";
import { useState } from "react";
import { run, useHue, useTarget } from "./hue";
import { meshSvg } from "./svg";
import { svgFile } from "./svg-files";
import type { HueScene } from "./types";

// Scenes of a room. On a light target only that light's part of the scene is applied.
export function SceneList({ targetId }: { targetId: string }) {
  const target = useTarget(targetId);
  const { revalidate } = useHue();
  const [showHidden, setShowHidden] = useState(false);
  const room = target?.room;

  if (!target || !room) {
    return (
      <Grid>
        <Grid.EmptyView icon={Icon.LightBulbOff} title="Not in a room" description="Only rooms have scenes." />
      </Grid>
    );
  }

  const item = (scene: HueScene) => (
    <Grid.Item
      key={scene.id}
      title={scene.name}
      subtitle={scene.id === room.activeSceneID ? "✓ Active" : undefined}
      content={{ source: svgFile(meshSvg(scene.colours)) }}
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

  return (
    <Grid columns={3} aspectRatio="3/2" navigationTitle={`${target.name} Scenes`} searchBarPlaceholder="Search scenes">
      <Grid.Section title={room.name}>{room.scenes.map(item)}</Grid.Section>
      {showHidden && <Grid.Section title="Hidden">{room.disabledScenes.map(item)}</Grid.Section>}
    </Grid>
  );
}
