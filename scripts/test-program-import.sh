#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$(bash "$repo/scripts/prepare-source.sh")"
tests="$(mktemp -d)"
trap 'rm -rf -- "$tests"' EXIT

cat > "$tests/ProgramImportTest.java" <<'JAVA'
import com.winlator.core.WindowsProgramFile;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.file.Files;
import java.nio.file.Path;

public class ProgramImportTest {
    public static void main(String[] args) throws Exception {
        Path directory = Path.of(args[0]);
        Path exe = directory.resolve("test.exe");
        ByteBuffer header = ByteBuffer.allocate(512).order(ByteOrder.LITTLE_ENDIAN);
        header.putShort(0, (short) 0x5a4d);
        header.putInt(0x3c, 64);
        header.putInt(64, 0x4550);
        header.putShort(86, (short) 2);

        for (int machine : new int[]{0x014c, 0x8664, 0xaa64}) {
            header.putShort(68, (short) machine);
            Files.write(exe, header.array());
            require(WindowsProgramFile.matchesFormat(exe.toFile()) == (machine != 0xaa64), "PE machine");
        }
        header.putShort(68, (short) 0x8664);
        header.putShort(86, (short) 0x2002);
        Files.write(exe, header.array());
        require(!WindowsProgramFile.matchesFormat(exe.toFile()), "DLL rejection");
        header.putInt(0x3c, -1);
        Files.write(exe, header.array());
        require(!WindowsProgramFile.matchesFormat(exe.toFile()), "PE bounds");

        Path msi = directory.resolve("test.msi");
        byte[] compound = ByteBuffer.allocate(512).putLong(0xd0cf11e0a1b11ae1L).array();
        Files.write(msi, compound);
        require(WindowsProgramFile.matchesFormat(msi.toFile()), "MSI compound document");
        Files.write(msi, new byte[12]);
        require(!WindowsProgramFile.matchesFormat(msi.toFile()), "truncated MSI");

        require("Game Setup.exe".equals(WindowsProgramFile.safeFilename("Game Setup.EXE")), "EXE name");
        require("program_CON.msi".equals(WindowsProgramFile.safeFilename("CON.msi")), "reserved DOS name");
        require(".._game.exe".equals(WindowsProgramFile.safeFilename("../game.exe")), "path delimiter");
        require(WindowsProgramFile.safeFilename("game.zip") == null, "unsupported extension");
        System.out.println("Windows program validation passed.");
    }

    private static void require(boolean condition, String test) {
        if (!condition) throw new AssertionError(test);
    }
}
JAVA

javac -d "$tests" "$source_dir/app/src/main/java/com/winlator/core/WindowsProgramFile.java" "$tests/ProgramImportTest.java"
java -cp "$tests" ProgramImportTest "$tests"
