#!/bin/bash
# aro (the C frontend behind 0.16's translate-c) decides whether Apple blocks
# (`^`) are a language feature per target, and its `isBlocksSupported` still
# reads `Os.isAtLeast` under the contract 0.15 had: `null` when the OS tag
# differs. 0.16's `isAtLeast` answers `false` on a tag mismatch, so iOS and
# the simulator translate CoreGraphics with blocks off (`CGPath.h:392: error:
# blocks are not enabled`). Ask the version question only for macOS and
# answer yes for the rest of Darwin.
#
# Zig 0.16 unpacks packages under <source>/zig-pkg/<name-version-hash>/
# (gitignored upstream), so they are patched there: fetched first when the
# tree is fresh, edited in place after. A later build never re-unpacks a
# package that is already there, so the edit survives.
set -euo pipefail
SOURCE_DIR=${1:?usage: $0 <ghostty_source_dir>}
SUPPORT_DIR="$(cd "$(dirname "$0")/../../Script/support" && pwd)"
cd "$SOURCE_DIR"

if ! ls -d zig-pkg/aro-* >/dev/null 2>&1; then
    # The default `--fetch` (`needed`) unpacks only eager dependencies; `all`
    # fetches the whole tree, which later builds expect. Cache dirs come from
    # the environment when the caller exported them.
    zig build --fetch=all >/dev/null
fi

for dir in zig-pkg/aro-*; do
    [ -d "$dir" ] || { echo "[!] no aro package under zig-pkg/ after fetch"; exit 1; }
    PYTHONPATH="$SUPPORT_DIR" python3 - "$dir" <<'PY'
import sys

from anchored_edit import Source

src = Source(sys.argv[1], "src/aro/Target.zig")
src.replace(
    """        if (target.os.isAtLeast(.macos, .{ .major = 10, .minor = 6, .patch = 0 })) |sup| return sup;
        // TODO: do iOS or other OSes have a min version?
        return target.os.tag != .macos;
""",
    """        // Zig 0.16's isAtLeast answers false, not null, for another OS
        // tag; ask it about macOS only. (libghostty-spm)
        if (target.os.tag != .macos) return true;
        return target.os.isAtLeast(.macos, .{ .major = 10, .minor = 6, .patch = 0 }) orelse false;
""",
)
src.save()
PY
done

echo "[+] all zig-pkg Apple target patches applied"
