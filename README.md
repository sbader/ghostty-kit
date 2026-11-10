# ghostty-kit

Builds `GhosttyKit.xcframework` (arm64 macOS, iOS, iOS Simulator) from Ghostty at `Ghostty.ref` with `Patches/ghostty`. `Patches/vt` is sandbox-manager's `libghostty-vt` queue for the same pin.

## Requirements

- Zig 0.17.1
- macOS with Xcode and the Metal toolchain (`xcodebuild -downloadComponent MetalToolchain`) for builds; Linux or macOS for tests

## Commands

| Command | Purpose |
|---|---|
| `Script/build.sh [--source <checkout>]` | Build `.build/GhosttyKit.xcframework` and its zip |
| `Script/test.sh [--source <checkout>]` | Check both patch queues and run the patch Zig tests |
| `Script/verify-xcframework.sh <xcframework\|zip>` | Check slices, identity and required symbols |
| `Script/test-xcframework-consumer.sh [xcframework]` | Build a Swift package against the xcframework |

## Releases

`release.yml` (manual) publishes `GhosttyKit.xcframework.zip` on the tag from `Script/storage-tag.sh`: `upstream.<first 12 of Ghostty.ref>`, with `-<Ghostty.build>` when `Ghostty.build` is 2 or more. Bump `Ghostty.build` to rebuild the same Ghostty commit.
