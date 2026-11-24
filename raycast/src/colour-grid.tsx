import { Action, ActionPanel, Grid, Icon } from "@raycast/api";
import { useState } from "react";
import { run, useHue, useTarget } from "./hue";
import { WHITES, hsvToHex, parseColourQuery } from "./lib";

// 8 columns is the most a Grid allows: eight hues, pale to full saturation downwards
const HUES = [0, 30, 55, 120, 175, 215, 270, 320];
const SATURATIONS = [0.3, 0.55, 0.8, 1];

export function ColourGrid({ targetId }: { targetId: string }) {
  const target = useTarget(targetId);
  const { revalidate } = useHue();
  const [search, setSearch] = useState("");
  if (!target) return <Grid />;

  const typed = parseColourQuery(search);
  const swatch = (key: string, title: string, hex: string, value: string, extra?: string[]) => (
    <Grid.Item
      key={key}
      id={key}
      title={title}
      content={{ color: hex }}
      keywords={extra}
      actions={
        <ActionPanel>
          <Action
            title="Set Colour"
            icon={Icon.Brush}
            onAction={() => run(["colour", target.id, value], `${target.name} set to ${title}`, revalidate)}
          />
        </ActionPanel>
      }
    />
  );

  return (
    <Grid
      columns={8}
      aspectRatio="1"
      navigationTitle={`${target.name} Colour`}
      searchBarPlaceholder="Search, or type a hex colour or CSS colour name"
      onSearchTextChange={setSearch}
    >
      {typed && target.supportsColor && (
        <Grid.Section title="Typed">{swatch("typed", typed.label, typed.hex, typed.hex, [search])}</Grid.Section>
      )}
      <Grid.Section title="White">
        {WHITES.map((w) => swatch(`white-${w.kelvin}`, `${w.name} ${w.kelvin}K`, w.hex, `${w.kelvin}K`))}
      </Grid.Section>
      {target.supportsColor && (
        <Grid.Section title="Colours">
          {SATURATIONS.flatMap((s) =>
            HUES.map((h) => {
              const hex = hsvToHex(h, s, 1);
              return swatch(`hsv-${h}-${s}`, hex, hex, hex);
            }),
          )}
        </Grid.Section>
      )}
    </Grid>
  );
}
