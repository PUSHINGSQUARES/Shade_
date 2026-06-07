<p align="center">
  <img src="icon.png" width="140" alt="Shade_ icon" />
</p>

# Shade_

`Shade_` is a macOS menu-bar app for live screen reading comfort. It places a
click-through colour and dim layer over every connected display, so you can warm
your screen and cut blue light at night without a global display tint.

Unlike system-wide warmth (which tints everything, including the shot you're
grading), `Shade_` can keep chosen app windows visually clear with **Passthrough** —
so your colour-critical work stays true while the rest of the screen stays calm.
The colour overlay also doubles as an Irlen-style **reading tint** for on-screen
legibility.

## Install

Download the latest signed, notarised `.dmg` from the
[Releases](../../releases) page, open it, and drag `Shade_` to Applications.

If you copy the app manually, use `cp -Rp` and do not re-codesign it, so the
app's entitlements are preserved.

## Build from source

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Xcode.

```bash
xcodegen generate
xcodebuild test -project Shade_.xcodeproj -scheme Shade_ \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Usage

1. Launch `Shade_`.
2. Open the menu bar item.
3. Toggle the shared `On` switch.
4. Adjust `Hue`, `Opacity`, and `Dim`.
5. Use `Reset Overlay Defaults` to return to the baseline.
6. Use `Passthrough...` to choose running apps whose windows should stay visually
   clear while `Shade_` remains on.
7. Use `Schedule...` to enable manual local-time start and end rules.
8. Use `Turn Off Now` or `Cmd + Opt + Shift + S` to disable quickly.

## How it works

`Shade_` runs as a **click-through colour and dim overlay**. It does not read your
display pixels, so it needs **no Screen Recording permission**. Windows underneath
the overlay stay fully interactive.

### Overlay controls

- `Hue` — the overlay colour (warm amber through any tint you choose).
- `Opacity` — how strong the colour layer is.
- `Dim` — an additional darkening layer.
- `Reset Overlay Defaults` — return to the baseline overlay.

The overlay composites over your screen, so it can only **add** light and colour —
it cannot darken pixels beneath it or recover colour under the tint. It is a comfort
layer, not a pixel transform.

### Passthrough

`Passthrough...` opens a picker of running apps. Each app you pass through has its
windows kept visually clear by cutting holes through the overlay. The holes are
live-tracked as windows move and resize, so the clear areas follow the windows in
real time. `Shade_` stays on globally while everything else remains tinted and
dimmed.

Passthrough rules are app-level: all visible windows from a chosen app are cleared.

### Scheduling

`Schedule...` opens a manual local-time scheduler. It stores whether the schedule
is enabled and the start and end times as `HH:mm`. Schedules can cross midnight —
for example, `20:00` to `08:00` turns `Shade_` on from 8pm through the morning and
off at 8am.

## Persisted settings

`Shade_` saves your overlay `Hue`, `Opacity`, and `Dim`, your passthrough apps, and
your manual schedule locally. Each launch starts with `Shade_` off, then restores
your saved controls, passthrough apps, and schedule.

## License

MIT — see [LICENSE](LICENSE).
