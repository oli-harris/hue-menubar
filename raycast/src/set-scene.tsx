import { Action, Icon } from "@raycast/api";
import { SceneList } from "./scene-list";
import { TargetList } from "./targets";

export default function Command() {
  return (
    <TargetList
      primary={(t) => <Action.Push title="Choose Scene" icon={Icon.Wand} target={<SceneList targetId={t.id} />} />}
    />
  );
}
