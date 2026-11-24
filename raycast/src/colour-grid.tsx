import { Action, ActionPanel, Grid, Icon } from "@raycast/api";
import { useState } from "react";
import { run, useHue, useTarget } from "./hue";
import { WHITES, exactColour, hsvToHex, colourName, parseColourQuery, saturationPercent } from "./lib";

// 8 columns is the most a Grid allows: eight hues, pale to full saturation downwards
const HUES = [0, 30, 55, 120, 175, 215, 270, 320];
const SATURATIONS = [0.25, 0.5, 0.75, 1];

// The selected swatch is named in the navigation title, since the swatches carry no text
function describe(id: string | null, typed?: { hex: string; label: string }): string | undefined {
  const [kind, a, b] = (id ?? "").split("-");
  if (kind === "white") return WHITES.find((w) => String(w.kelvin) === a)?.name + ` · ${a}K`;
  if (kind === "hsv") return `${colourName(hsvToHex(Number(a), 1, 1))} · ${Math.round(Number(b) * 100)}%`;
  if (kind === "typed" && typed) return `${colourName(typed.hex)} · ${saturationPercent(typed.hex)}%`;
  return undefined;
}

export function ColourGrid({ targetId }: { targetId: string }) {
  const target = useTarget(targetId);
  const { revalidate } = useHue();
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState<string | null>(null);
  if (!target) return <Grid />;

  const typed = parseColourQuery(search);
  const swatch = (key: string, name: string, hex: string, value: string, extra?: string[]) => (
    <Grid.Item
      key={key}
      id={key}
      content={{ color: exactColour(hex) }}
      keywords={extra}
      actions={
        <ActionPanel>
          <Action
            title="Set Colour"
            icon={Icon.Brush}
            onAction={() => run(["colour", target.id, value], `${target.name} set to ${name}`, revalidate)}
          />
        </ActionPanel>
      }
    />
  );

  return (
    <Grid
      columns={8}
      aspectRatio="1"
      navigationTitle={describe(selected, typed) ?? `${target.name} Colour`}
      searchBarPlaceholder="Search, or type a hex colour or CSS colour name"
      onSearchTextChange={setSearch}
      onSelectionChange={setSelected}
    >
      {typed && target.supportsColor && (
        <Grid.Section title="Typed">{swatch("typed", typed.label, typed.hex, typed.hex, [search])}</Grid.Section>
      )}
      <Grid.Section title="White">
        {WHITES.map((w) => swatch(`white-${w.kelvin}`, `${w.name} ${w.kelvin}K`, w.hex, `${w.kelvin}K`, [w.name]))}
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
