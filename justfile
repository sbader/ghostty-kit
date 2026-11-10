# Show commands
default:
    @just --list

# Pin Ghostty to a ref (default: main) and check the patch queues against it
bump ref="main":
    ./Script/bump.sh {{quote(ref)}}

# Check both patch queues and run the patch Zig tests
test:
    ./Script/test.sh

# Build .build/GhosttyKit.xcframework and its zip
build:
    ./Script/build.sh

# Check the local build's slices, identity and symbols, and build a consumer against it
verify:
    ./Script/verify-xcframework.sh .build/GhosttyKit.xcframework
    ./Script/test-xcframework-consumer.sh .build/GhosttyKit.xcframework

# Publish the release for the pushed Ghostty.ref and Ghostty.build
release:
    ./Script/release.sh
