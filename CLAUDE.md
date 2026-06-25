# CLAUDE.md — working notes for ClickShot

ClickShot is a native macOS menu-bar screenshot tool (Swift + AppKit +
ScreenCaptureKit). See `PRD.md` for the full product/feature/architecture spec.

## Conventions (follow these every time)

- **Always update `PRD.md` as part of any commit that changes behavior.** Keep its
  feature list and interaction table in sync with the code.
- **Record important technical solutions in `PRD.md`** (the "Technical solutions &
  key decisions" section): when a non-obvious approach is chosen (a workaround, an
  OS quirk, a tradeoff), add a short entry explaining *what* and *why* so it isn't
  re-litigated later.
- Commit messages end with the `Co-Authored-By` trailer; tag releases `vX.Y` with
  an annotated tag.

## Build / run

```sh
./scripts/build-app.sh           # build + assemble + sign build/ClickShot.app
open build/ClickShot.app
./scripts/notarize.sh            # notarize (Developer ID builds)
```

Requires **Accessibility** (global event tap) and **Screen Recording** (capture)
permissions. The build script auto-detects a signing identity (Developer ID →
Apple Development → ad-hoc); a stable identity keeps TCC grants across rebuilds.
