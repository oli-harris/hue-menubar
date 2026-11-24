import { Action, Icon } from "@raycast/api";
import { TargetList, TargetMenu } from "./targets";

export default function Command() {
  return (
    <TargetList
      includeAll
      withMenu
      primary={(t) => <Action.Push title="Choose Action" icon={Icon.List} target={<TargetMenu targetId={t.id} />} />}
    />
  );
}
