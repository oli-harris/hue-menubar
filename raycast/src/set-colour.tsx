import { Action, Icon } from "@raycast/api";
import { ColourGrid } from "./colour-grid";
import { TargetList } from "./targets";

export default function Command() {
  return (
    <TargetList
      includeAll
      primary={(t) => <Action.Push title="Choose Colour" icon={Icon.Brush} target={<ColourGrid targetId={t.id} />} />}
    />
  );
}
