# Wound

> A watch you have to wind. On purpose.

Wound is a small macOS mechanical watch that is inconvenient by design.
Its 40-hour power reserve drains in real time, so the watch stops when you neglect it.
Scroll over its crown or drag upward to wind it again.
Your everyday mouse and keyboard activity also gives its automatic rotor a little energy.

The watch face is a skeleton Cal. W-28S drawn in Core Graphics, with an escapement, balance wheel, hairspring, train, exposed barrel, ratchet click, and a flip-to-caseback automatic rotor.

![Skeleton dial](screenshots/skeleton-running.png)

![Automatic caseback](screenshots/caseback-rotor.png)

## Run

Wound needs macOS 14 or later and the Swift toolchain that ships with Xcode or Command Line Tools.

```sh
swift run
```

Use the menu-bar extra to check the reserve without opening the floating window.
The Settings window has sound, always-on-top, automatic winding, and accelerated demo-speed controls.

## Interaction

- Scroll over the crown at 3 o'clock to wind it, one ratchet click at a time.
- Drag upward over that same crown if a mouse wheel is not available.
- Flip to the caseback to see the rotor react to automatic winding.
- Let it run out, then wind it back to life.

Winding is intentionally capped at 40 hours.
Past full reserve the crown gives visual resistance instead of adding more energy.
Reserve and the displayed time are saved in `UserDefaults`, so draining continues while Wound is closed.

## Tests

```sh
swift run Wound --self-test
```

The dependency-free Swift movement checks cover reserve drain, stopped-time behavior, winding saturation, automatic-winding saturation, and persistence encoding.

## Rendered demo

```sh
swift run Wound --render-demo demo/frames
ffmpeg -framerate 10 -i demo/frames/frame-%04d.png -c:v libx264 -pix_fmt yuv420p demo/wound-demo.mp4
```

The renderer makes a 24-second standalone movement reel: unwound, crown-wound, running, then caseback rotor.

## License

MIT.
The mechanical illustration is code in `Sources/Wound/Art`, not third-party artwork.
