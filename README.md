# Winblow

Winblow runs compatible Windows x86 and x64 applications and games locally on ARM64 Android. It builds on Winlator 11.2 with Wine 10.10 and Box64 0.4.4. Its Windows 10 and Windows 11 profiles set the Windows version reported to apps while sharing the Wine desktop and translation engine.

## Open a program

1. Install the arm64 APK on Android 8 or later and open Winblow. Let it unpack the bundled runtime.
2. Select **Create desktop** and choose a Windows 10 or 11 compatibility profile. Each desktop has its own C: drive, installed apps and registry.
3. Open the desktop menu and select **Try Notepad** to check the Wine session. Use Android Back to show the session controls and choose **Exit** when finished.
4. Select **Import and run EXE or MSI** in the desktop menu. Winblow copies the selected file into the desktop's WinblowImports folder and opens it. For an installer or game with multiple files, keep the entire folder together in Android Downloads, select **Allow access to Downloads**, and open the program from **D:** inside the desktop.

The desktop provides a touchpad, on-screen keyboard, input profiles, and external mouse and gamepad support. The quick setup uses VirGL and WineD3D on non-Adreno devices and starts at 960×540 on phones with under 5 GB of RAM, including the 4 GB Redmi 13C 5G. Start with lightweight programs or older games. Performance and compatibility depend on the game, Android version and GPU. Windows kernel drivers and many anti-cheat systems are incompatible with Wine.

## Build

Use Linux with Bash, Git, Python 3, zstd, and JDK 17. Set ANDROID_HOME to an SDK with the following packages.

~~~sh
sdkmanager 'platform-tools' 'platforms;android-35' 'build-tools;34.0.0' 'ndk;24.0.8215888' 'cmake;3.22.1'
./scripts/build.sh
~~~

The build fetches the pinned Winlator source, applies the Winblow patch, relocates the prebuilt runtime to Winblow's separate Android package and validates the signed debug APK. The result is dist/Winblow-0.1.0-arm64.apk. The generated Android Studio project lives under .build/engine-* and can also be prepared with ./scripts/prepare-source.sh.

GitHub Actions builds the same APK and provides it as an artifact for each successful main-branch run.

## Sources and licenses

Winblow's app changes use the LGPL 2.1 license. The build uses Wine's built-in Windows components. It filters the upstream optional native Windows DLL packs and Microsoft core fonts from the generated app.

- [Winlator app source at the pinned revision](https://github.com/brunodev85/winlator-app/tree/2c33741d50c5daab0521a098be5c969f63b9e887), by BrunoSX and contributors.
- [Wine 10.10 custom](https://github.com/brunodev85/wine-10.10-custom), [Box64](https://github.com/brunodev85/box64), and [glibc packaging and patches](https://github.com/termux-pacman/glibc-packages).
- [Mesa](https://gitlab.freedesktop.org/mesa/mesa), [Winlator Mesa fork](https://github.com/brunodev85/mesa3d-custom), [Vortek](https://github.com/brunodev85/vortek), and [Gladio](https://github.com/brunodev85/gladio).
- [DXVK](https://github.com/doitsujin/dxvk), [VKD3D](https://gitlab.winehq.org/wine/vkd3d), [D7VK](https://github.com/WinterSnowfall/d7vk), and [CNC DDraw](https://github.com/FunkyFr3sh/cnc-ddraw).
- [Winlator File Manager](https://github.com/brunodev85/wfm), [Winlator add-ons](https://github.com/brunodev85/winlator-addons), [7-Zip](https://www.7-zip.org/), and [FluidSynth](https://www.fluidsynth.org/).
