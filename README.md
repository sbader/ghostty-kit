# ghostty-kit

Builds `GhosttyKit.xcframework` (arm64 macOS, iOS, iOS Simulator) from Ghostty at `Ghostty.ref` with `Patches/ghostty`. `Patches/vt` is sandbox-manager's `libghostty-vt` queue for the same pin.

## Requirements

- Zig 0.17.1
- macOS with Xcode and the Metal toolchain (`xcodebuild -downloadComponent MetalToolchain`) for builds; Linux or macOS for tests

## Commands

| Command | Purpose |
|---|---|
| `just bump [ref]` | Pin `Ghostty.ref` to a Ghostty ref (default `main`) and run `just test` |
| `just test` | Check both patch queues and run the patch Zig tests |
| `just build` | Build `.build/GhosttyKit.xcframework` and its zip |
| `just verify` | Check the local build and build a consumer against it |
| `just release` | Publish the pushed `Ghostty.ref` and `Ghostty.build` through `release.yml` |

## Bumping Ghostty

1. `just bump [ref]`, fix failing patches, `just build`
2. App and sandbox-manager: `just terminal local <ghostty-kit checkout>`, then test
3. Commit and push, then app `just terminal release`
4. sandbox-manager: `just terminal update`

## Releases

`release.yml` (manual) publishes `GhosttyKit.xcframework.zip` on the tag from `Script/storage-tag.sh`: `upstream.<first 12 of Ghostty.ref>`, with `-<Ghostty.build>` when `Ghostty.build` is 2 or more. Bump `Ghostty.build` to rebuild the same Ghostty commit.
