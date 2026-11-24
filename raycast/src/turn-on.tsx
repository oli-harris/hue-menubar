import { Action, Icon } from "@raycast/api";
import { run } from "./hue";
import { TargetList } from "./targets";

export default function Command() {
  return (
    <TargetList
      includeAll
      primary={(t, revalidate) => (
        <Action title="Turn on" icon={Icon.LightBulb} onAction={() => run(["on", t.id], `${t.name} on`, revalidate)} />
      )}
    />
  );
}
