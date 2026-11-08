# Winblow

Winblow runs compatible Windows x86 and x64 applications and games locally on ARM64 Android. It builds on Winlator 11.2 with Wine 10.10 and Box64 0.4.4. Its Windows 10 and Windows 11 profiles set the Windows version reported to apps while sharing the Wine desktop and translation engine.

## Open a program

1. Install the arm64 APK on Android 8 or later and open Winblow. Let it unpack the bundled runtime.
2. Select **Create desktop** and choose a Windows 10 or 11 compatibility profile. Each desktop has its own C: drive, installed apps and registry.
3. Open the desktop menu and select **Try Notepad** to check the Wine session. Use Android Back to show the session controls and choose **Exit** when finished.
4. Select **Import and run EXE or MSI** in the desktop menu. Winblow copies the selected file into the desktop's WinblowImports folder and opens it. For an installer or game with multiple files, keep the entire folder together in Android Downloads, select **Allow access to Downloads**, and open the program from **D:** inside the desktop.

The desktop provides a touchpad, on-screen keyboard, input profiles, and external mouse and gamepad support. OpenGL ES 3.0 or later powers the Android compositor. Start with lightweight programs or older games. Performance and compatibility depend on the game, Android version and GPU. Windows kernel drivers and many anti-cheat systems are incompatible with Wine.

## Graphics and performance

Open the desktop menu and choose **Graphics presets**. Winblow shows the detected GPU, the Vulkan version Android advertises, and the proposed rendering stack. Choose a resolution and optionally enable the FPS overlay.

| Preset | Rendering path |
| --- | --- |
| Auto | Turnip on eligible Adreno 6xx and 7xx devices, Vortek on higher-memory devices with Android Vulkan 1.3, or VirGL |
| Vulkan gaming | Turnip or the Android Vulkan driver through Vortek, with DXVK |
| VirGL compatibility | VirGL and WineD3D with guest Vulkan disabled |
| Gladio OpenGL ES | Gladio and WineD3D with guest Vulkan disabled |
| Zink OpenGL over Vulkan | Zink through Turnip or Vortek |
| Retro DirectDraw | CNC DDraw with Gladio |
| Safe desktop | WineD3D GDI at 800×600 for recovery |

The Redmi 13C 5G starts with VirGL and WineD3D at 960×540 under Auto. Lower-memory Vulkan presets start at 30 FPS, advertise a smaller graphics memory budget, and use two DXVK shader compilation workers. The frame cap and resolution are adjustable per desktop.

**Open with safe graphics** applies GDI and Box64 stability settings for one launch. Startup recovery offers that same path after a failed or slow start. It opens the desktop directly and leaves program launch to you.

Advanced editing exposes Turnip 24.1.0, 25.0.0, 26.0.3, and 26.2.0, DXVK 1.10.3, 2.4.1, and 3.1.1, plus VKD3D-Proton 2.14.1 and 3.1. Newer translators are opt-in and depend on the Vulkan features exposed by the selected driver. The launch checks choose an older translator when a known requirement is missing. [DXVK requirements](https://github.com/doitsujin/dxvk/wiki/Driver-support)

Frame copies use OpenGL ES 3.2 when available and framebuffer blits on ES 3.0 and 3.1. Offscreen contexts can use a pbuffer when the Android driver needs a surface.

## Build

Use Linux with Bash, Git, curl, Python 3, zstd, and JDK 17. Set ANDROID_HOME to an SDK with the following packages.

~~~sh
sdkmanager 'platform-tools' 'platforms;android-35' 'build-tools;34.0.0' 'ndk;24.0.8215888' 'cmake;3.22.1'
./scripts/build.sh
~~~

The build fetches the pinned Winlator source, applies the Winblow patches, verifies the extra graphics packages, relocates the prebuilt runtime to Winblow's separate Android package and validates the signed debug APK. The result is dist/Winblow-0.2.0-arm64.apk. The generated Android Studio project lives under .build/engine-* and can also be prepared with ./scripts/prepare-source.sh.

GitHub Actions builds the same APK and provides it as an artifact for each successful main-branch run.

These are development builds signed with the builder's `~/.android/debug.keystore`. Preserve that private key for future updates. Builds from a fresh machine or CI runner can use a different signer and require a fresh install. Copy needed C: files to the Downloads drive before uninstalling an older build; uninstalling deletes private app data.

## Sources and licenses

Winblow's app changes use the LGPL 2.1 license. The build uses Wine's built-in Windows components. It filters the upstream optional native Windows DLL packs and Microsoft core fonts from the generated app.

- [Winlator app source at the pinned revision](https://github.com/brunodev85/winlator-app/tree/2c33741d50c5daab0521a098be5c969f63b9e887), by BrunoSX and contributors.
- [Wine 10.10 custom](https://github.com/brunodev85/wine-10.10-custom), [Box64](https://github.com/brunodev85/box64), and [glibc packaging and patches](https://github.com/termux-pacman/glibc-packages).
- [Mesa](https://gitlab.freedesktop.org/mesa/mesa), [Winlator Mesa fork](https://github.com/brunodev85/mesa3d-custom), [Vortek](https://github.com/brunodev85/vortek), and [Gladio](https://github.com/brunodev85/gladio).
- [DXVK](https://github.com/doitsujin/dxvk), [VKD3D](https://gitlab.winehq.org/wine/vkd3d), [D7VK](https://github.com/WinterSnowfall/d7vk), and [CNC DDraw](https://github.com/FunkyFr3sh/cnc-ddraw).
- [Winlator File Manager](https://github.com/brunodev85/wfm), [Winlator add-ons](https://github.com/brunodev85/winlator-addons), [7-Zip](https://www.7-zip.org/), and [FluidSynth](https://www.fluidsynth.org/).

- [Optional Turnip builds](https://github.com/brunodev85/winlator/tree/30aafbdb9eea47b92669201621e03cd2cf04540d/installable_components/turnip), [DXVK 3.1.1](https://github.com/doitsujin/dxvk/tree/v3.1.1), and [VKD3D-Proton 3.1](https://github.com/HansKristian-Work/vkd3d-proton/tree/v3.1).
