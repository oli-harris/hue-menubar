import { Action, Icon } from "@raycast/api";
import { run } from "./hue";
import { TargetList } from "./targets";

export default function Command() {
  return (
    <TargetList
      includeAll
      primary={(t, revalidate) => (
        <Action
          title="Turn off"
          icon={Icon.LightBulbOff}
          onAction={() => run(["off", t.id], `${t.name} off`, revalidate)}
        />
      )}
    />
  );
}
