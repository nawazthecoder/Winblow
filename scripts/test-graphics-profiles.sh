#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$(bash "$repo/scripts/prepare-source.sh")"
classes="$source_dir/app/build/intermediates/javac/debug/compileDebugJavaWithJavac/classes"
tests="$(mktemp -d)"
trap 'rm -rf -- "$tests"' EXIT
cat > "$tests/GraphicsProfileTest.java" <<'JAVA'
import com.winlator.container.DXWrappers;
import com.winlator.container.GraphicsDrivers;
import com.winlator.container.GraphicsProfile;
import com.winlator.core.KeyValueSet;

public class GraphicsProfileTest {
    private static final int VK_1_1 = (1 << 22) | (1 << 12);
    private static final int VK_1_3 = (1 << 22) | (3 << 12);

    public static void main(String[] args) {
        int recommended = GraphicsProfile.RECOMMENDED_FRAME_CAP;
        GraphicsProfile.Settings mali = GraphicsProfile.AUTO.resolve(VK_1_1, 0, true, recommended);
        require(mali.drivers.equals("none,virgl") && mali.wrapper.equals("wined3d"), "Mali low-memory graphics");
        require(mali.resolution.equals("960x540"), "Mali low-memory resolution");
        GraphicsProfile.Settings adreno = GraphicsProfile.AUTO.resolve(VK_1_3, 730, true, recommended);
        require(adreno.drivers.equals("turnip,gladio") && adreno.wrapper.equals("dxvk"), "Adreno fast path");
        KeyValueSet budget = new KeyValueSet(adreno.wrapperConfig);
        require(budget.getInt("framerate") == 30 && budget.getInt("compilerThreads") == 2, "DXVK budgets");
        GraphicsProfile.Settings system = GraphicsProfile.AUTO.resolve(VK_1_3, 0, false, recommended);
        require(system.drivers.equals("vortek,virgl") && system.wrapper.equals("dxvk"), "Android Vulkan path");
        require(new KeyValueSet(system.wrapperConfig).getInt("framerate") == 60, "Balanced frame cap");
        GraphicsProfile.Settings older = GraphicsProfile.VULKAN.resolve(VK_1_1, 530, false, 45);
        require(older.drivers.equals("vortek,virgl"), "Older Adreno uses Android's driver");
        require(new KeyValueSet(older.wrapperConfig).getInt("framerate") == 45, "Custom frame cap");
        require(new KeyValueSet(GraphicsProfile.VULKAN.resolve(VK_1_3, 740, false, 0).wrapperConfig)
            .get("framerate").isEmpty(), "Uncapped setting");
        require(!GraphicsProfile.ZINK.isAvailable(VK_1_1), "Zink Vulkan minimum");
        require(GraphicsProfile.VULKAN.resolve(0, 0, false, 60).drivers.equals("none,virgl"), "Vulkan absence");
        GraphicsProfile.Settings safe = GraphicsProfile.SAFE.resolve(0, 0, false, recommended);
        require(safe.drivers.equals("none,none") && safe.wrapperConfig.equals("renderer=gdi"), "Safe desktop");
        require(GraphicsProfile.RETRO.resolve(0, 0, true, recommended).wrapperConfig.contains("cnc-ddraw"), "Retro DirectDraw");
        require(GraphicsDrivers.parseIdentifiers("none,none")[1].equals("none"), "Disabled driver encoding");
        require(GraphicsDrivers.parseIdentifiers("turnip,")[1].equals("gladio"), "Partial saved driver");
        KeyValueSet[] graphics = GraphicsDrivers.parseConfigs("vortek,virgl", "|glVersion=3.1");
        require(graphics[0].get("glVersion").isEmpty() && graphics[1].get("glVersion").equals("3.1"), "OpenGL config slot");
        KeyValueSet[] dx = DXWrappers.parseConfigs("dxvk", "version=3.1,featureLevel=12.1");
        require(dx[0].get("version").isEmpty() && dx[1].get("version").equals("3.1"), "Legacy DX12 config slot");
        System.out.println("Graphics profiles and saved configuration tests passed.");
    }
    private static void require(boolean condition, String test) {
        if (!condition) throw new AssertionError(test);
    }
}
JAVA
javac -cp "$classes" -d "$tests" "$tests/GraphicsProfileTest.java"
java -cp "$tests:$classes" GraphicsProfileTest
