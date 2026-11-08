#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="${WINBLOW_TEST_SOURCE:-$(bash "$repo/scripts/prepare-source.sh")}"
tests="$(mktemp -d)"
trap 'rm -rf -- "$tests"' EXIT
cat > "$tests/GraphicsCapabilitiesTest.java" <<'JAVA'
import com.winlator.container.GraphicsCapabilities;
public final class GraphicsCapabilitiesTest {
    static void require(boolean value, String name) {
        if (!value) throw new AssertionError(name);
    }
    public static void main(String[] args) {
        require(!new GraphicsCapabilities(null).supportsModernDxvk(), "Unknown hardware must not pass");
        require(!new GraphicsCapabilities(new long[]{1}).supportsModernDxvk(), "Truncated native response");
        long[] data = {GraphicsCapabilities.VULKAN_1_3, 256, 1, 1, 1, 1, 1, 63, 0x5143, 1, 16384, 0};
        require(new GraphicsCapabilities(data).supportsModernDxvk(), "Complete capabilities");
        data[1] = 128;
        require(new GraphicsCapabilities(data).modernDxvkBlockers().contains("256-byte push constants"), "128-byte driver regression");
        data[1] = 256;
        for (int i = 2; i <= 6; i++) {
            data[i] = 0;
            require(!new GraphicsCapabilities(data).supportsModernDxvk(), "Missing required feature " + i);
            data[i] = 1;
        }
        for (int bit = 0; bit < 6; bit++) {
            data[7] = 63 & ~(1 << bit);
            require(new GraphicsCapabilities(data).modernDxvkBlockers().size() == 1, "Missing required extension " + bit);
        }
        data[7] = 63;
        data[0] = (1 << 22) | (1 << 12);
        require(!new GraphicsCapabilities(data).supportsModernDxvk(), "Vulkan 1.1 cannot pass modern preflight");
        System.out.println("Vulkan capability policy: unknown hardware, push-constant limits, features and extension gaps passed.");
    }
}
JAVA
javac -d "$tests" "$source_dir/app/src/main/java/com/winlator/container/GraphicsCapabilities.java" "$tests/GraphicsCapabilitiesTest.java"
java -cp "$tests" GraphicsCapabilitiesTest
