import { Action, Icon } from "@raycast/api";
import { BrightnessGrid } from "./brightness-grid";
import { TargetList } from "./targets";

export default function Command() {
  return (
    <TargetList
      includeAll
      primary={(t) => (
        <Action.Push title="Choose Brightness" icon={Icon.LightBulb} target={<BrightnessGrid targetId={t.id} />} />
      )}
    />
  );
}
