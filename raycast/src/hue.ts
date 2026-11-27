import { Toast, getPreferenceValues, showToast } from "@raycast/api";
import { useExec } from "@raycast/utils";
import { execFile } from "node:child_process";
import { buildTargets } from "./lib";
import type { HueData, Target } from "./types";

export type HueErrorKind = "missing" | "unpaired" | "failed";

export class HueError extends Error {
  constructor(
    readonly kind: HueErrorKind,
    message: string,
  ) {
    super(message);
  }
}

export const APP_BUNDLE_ID = "com.harris.huemenubar";

function hueBinary(): string {
  const { appPath } = getPreferenceValues<{ appPath?: string }>();
  return `${(appPath || "/Applications/huemenubar.app").replace(/\/+$/, "")}/Contents/Resources/hue`;
}

// Exit codes of the CLI: 1 failed (message on stderr), 2 not paired
function toError(result: { error?: Error; exitCode: number | null; stderr: string }): HueError {
  if ((result.error as NodeJS.ErrnoException | undefined)?.code === "ENOENT") {
    return new HueError("missing", "Hue Menubar was not found. Set its location in the extension preferences.");
  }
  if (result.exitCode === 2) return new HueError("unpaired", "Pair in Hue Menubar first");
  return new HueError("failed", result.stderr.trim() || result.error?.message || "Hue command failed");
}

// Cached: shows the last data at once. The first screen of a command fetches on mount; pushed screens
// pass false and read the shared cache, calling revalidate() only after an action.
export function useHue(fetchOnMount = true) {
  const { data, error, isLoading, revalidate } = useExec(hueBinary(), ["lights", "--json"], {
    timeout: 30000,
    execute: fetchOnMount,
    keepPreviousData: true,
    parseOutput: (r): HueData => {
      if (r.error || r.exitCode !== 0) throw toError(r);
      return JSON.parse(r.stdout);
    },
    // Setup problems get an empty view instead of a toast
    onError: (e) => {
      if (e instanceof HueError && e.kind === "failed")
        showToast({ style: Toast.Style.Failure, title: "Hue", message: e.message });
    },
  });
  return { data, error: error as HueError | undefined, isLoading, revalidate, targets: data && buildTargets(data) };
}

export function useTarget(id: string): { target?: Target; revalidate: () => void } {
  const { targets, revalidate } = useHue(false);
  const target =
    targets &&
    (targets.all.id === id ? targets.all : targets.sections.flatMap((s) => s.targets).find((t) => t.id === id));
  return { target, revalidate };
}

// Runs a CLI command, rejecting with a HueError. Pass ids, never names.
export function exec(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    execFile(hueBinary(), args, { timeout: 30000 }, (error, _stdout, stderr) => {
      if (!error) return resolve();
      reject(toError({ error, exitCode: typeof error.code === "number" ? error.code : null, stderr }));
    });
  });
}

// Runs a command with a toast, then refreshes the shown state
export async function run(args: string[], successTitle: string, revalidate?: () => void) {
  const toast = await showToast({ style: Toast.Style.Animated, title: "Working…" });
  try {
    await exec(args);
    toast.style = Toast.Style.Success;
    toast.title = successTitle;
    revalidate?.();
  } catch (e) {
    const error = e as HueError;
    toast.style = Toast.Style.Failure;
    toast.title = error.kind === "unpaired" ? error.message : "Hue failed";
    toast.message = error.kind === "unpaired" ? undefined : error.message;
  }
}
