import { Action, ActionPanel, Grid, Icon } from "@raycast/api";
import { useState } from "react";
import { run, useHue, useTarget } from "./hue";
import { dimColour, exactColour, parsePercent } from "./lib";

const LEVELS = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

export function BrightnessGrid({ targetId }: { targetId: string }) {
  const target = useTarget(targetId);
  const { revalidate } = useHue();
  const [search, setSearch] = useState("");
  if (!target) return <Grid />;

  const typed = parsePercent(search);
  const current = target.isOn ? Math.round((target.brightness ?? 100) / 10) * 10 : 0;
  const tile = (key: string, level: number) => (
    <Grid.Item
      key={key}
      id={key}
      title={level === 0 ? "Off" : `${level}%`}
      content={{ color: exactColour(dimColour(target.colour ?? "#ffd5b3", level)) }}
      keywords={key === "typed" ? [search] : undefined}
      actions={
        <ActionPanel>
          <Action
            title="Set Brightness"
            icon={Icon.LightBulb}
            onAction={() => run(["brightness", target.id, String(level)], `${target.name} at ${level}%`, revalidate)}
          />
        </ActionPanel>
      }
    />
  );

  return (
    <Grid
      columns={6}
      aspectRatio="1"
      navigationTitle={`${target.name} Brightness`}
      searchBarPlaceholder="Type a percentage from 0 to 100"
      selectedItemId={`level-${current}`}
      onSearchTextChange={setSearch}
    >
      {typed !== undefined && <Grid.Section title="Typed">{tile("typed", typed)}</Grid.Section>}
      <Grid.Section title="Brightness">{LEVELS.map((l) => tile(`level-${l}`, l))}</Grid.Section>
    </Grid>
  );
}
