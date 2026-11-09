#!/bin/bash
# Upstream's MetallibStep only knows macOS (`else => return null`), and
# SharedDeps unwraps the step for every Darwin target, so an iOS build
# panics at `self.metallib.?`. Give it the iOS device and simulator SDKs
# and their version flags.
set -euo pipefail
SOURCE_DIR=${1:?usage: $0 <ghostty_source_dir>}
SUPPORT_DIR="$(cd "$(dirname "$0")/../../Script/support" && pwd)"
PYTHONPATH="$SUPPORT_DIR${PYTHONPATH:+:$PYTHONPATH}" python3 - "$SOURCE_DIR" <<'PY'
import sys

from anchored_edit import Source

src = Source(sys.argv[1], "src/build/MetallibStep.zig")
src.replace(
    """    const sdk = switch (opts.target.result.os.tag) {
        .macos => "macosx",
        else => return null,
    };
""",
    """    const sdk = switch (opts.target.result.os.tag) {
        .macos => "macosx",
        .ios => switch (opts.target.result.abi) {
            .simulator => "iphonesimulator",
            else => "iphoneos",
        },
        else => return null,
    };
""",
)
src.replace(
    """    const platform_version_arg = switch (opts.target.result.os.tag) {
        .macos => "-mmacos-version-min",
        else => null,
    };
""",
    """    const platform_version_arg = switch (opts.target.result.os.tag) {
        .macos => "-mmacos-version-min",
        .ios => switch (opts.target.result.abi) {
            .simulator => "-mios-simulator-version-min",
            else => "-mios-version-min",
        },
        else => null,
    };
""",
)
src.replace(
    """        .macos => "10.14",
        else => unreachable,
""",
    """        .macos => "10.14",
        .ios => "11.0",
        else => unreachable,
""",
)
src.save()
PY
