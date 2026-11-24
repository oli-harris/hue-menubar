// Shapes of the Hue Menubar CLI's `lights --json` output
export interface HueLight {
  id: string;
  name: string;
  bridgeName: string;
  type?: string; // The bridge's archetype, e.g. floor_shade
  isOn: boolean;
  brightness?: number; // Percent, absent when the light can't dim
  colour?: string; // Approximate #rrggbb of what it shows
  supportsColor: boolean;
  supportsTemperature: boolean;
}

export interface HueScene {
  id: string;
  name: string;
  colours: string[];
}

export interface HueRoom {
  id: string;
  name: string;
  bridgeName: string;
  type?: string;
  isOn: boolean;
  brightness?: number;
  activeSceneID?: string;
  lights: HueLight[];
  scenes: HueScene[]; // Shown in the menu, in order
  disabledScenes: HueScene[];
}

export interface HueData {
  rooms: HueRoom[];
  unassigned: HueLight[];
}

// Something a command can act on: every light, a room or one light
export interface Target {
  id: string; // What the CLI takes: "all", a room id or a light id
  kind: "all" | "room" | "light";
  name: string;
  type?: string; // Archetype of the light or room
  room?: HueRoom; // The room itself, or the one a light is in
  isOn: boolean;
  brightness?: number;
  colour?: string;
  supportsColor: boolean;
}
