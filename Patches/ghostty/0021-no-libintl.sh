#!/bin/bash

set -euo pipefail

SOURCE_DIR="${1:?Usage: $0 <ghostty-source-dir>}"

# =============================================================================
# Link GNU libintl only when i18n is on
# =============================================================================
#
# Upstream links its bundled libintl (LGPL-2.1+) into every Darwin build
# whatever `-Di18n` says, so libghostty.a carried it. Statically linked, that
# puts a relinking obligation on the app. build-ghostty.sh passes
# `-Di18n=false`; this makes the link follow it.
#
# Without libintl, setLangFromCocoa puts raw BCP-47 tags in LANGUAGE. Only
# child processes of the app read it, and the app spawns none.
# =============================================================================

PYTHONPATH="$(cd "$(dirname "$0")/../../Script/support" && pwd)" python3 - "$SOURCE_DIR" <<'PY'
import sys

from anchored_edit import Source

source_dir = sys.argv[1]

src = Source(source_dir, "src/build/SharedDeps.zig")
src.replace(
    """        // Apple platforms do not include libc libintl so we bundle it.
        // This is LGPL but since our source code is open source we are
        // in compliance with the LGPL since end users can modify this
        // build script to replace the bundled libintl with their own.
        if (b.lazyDependency("libintl", .{
            .target = target,
            .optimize = optimize,
        })) |libintl_dep| {
            step.root_module.linkLibrary(libintl_dep.artifact("intl"));
            try static_libs.append(
                b.allocator,
                libintl_dep.artifact("intl").getEmittedBin(),
            );
        }
""",
    """        // ghostty-kit: libintl (LGPL) is linked only when i18n is on.
        if (self.config.i18n) {
            if (b.lazyDependency("libintl", .{
                .target = target,
                .optimize = optimize,
            })) |libintl_dep| {
                step.root_module.linkLibrary(libintl_dep.artifact("intl"));
                try static_libs.append(
                    b.allocator,
                    libintl_dep.artifact("intl").getEmittedBin(),
                );
            }
        }
""",
)
src.save()
PY

echo "[+] libintl linked only with i18n"
