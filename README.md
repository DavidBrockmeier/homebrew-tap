# Homebrew tap

A personal experimental replacement formula for **`molten-vk`**, with private
Metal APIs enabled by default. This tap deliberately
collides with `homebrew/core/molten-vk`: it uses the same Cellar name, opt link,
library names, and Vulkan driver-manifest location. It is not keg-only and is not
a separately named variant.

## Replace an existing installation

Quit applications using the driver before switching. With current Homebrew:

```sh
brew tap DavidBrockmeier/tap
brew trust --formula DavidBrockmeier/tap/molten-vk
brew reinstall --force --build-from-source DavidBrockmeier/tap/molten-vk
brew test DavidBrockmeier/tap/molten-vk
```

Homebrew's reinstall operation backs up the current keg while installing the
replacement and restores it if installation fails. A successful replacement
records this tap in the installation receipt. There is no need to force-uninstall
mpv or copy a dylib over Homebrew's files.

If `molten-vk` is not already installed:

```sh
brew install DavidBrockmeier/tap/molten-vk
```

The normal Apple Silicon library paths remain:

```text
/opt/homebrew/opt/molten-vk/lib/libMoltenVK.dylib
/opt/homebrew/lib/libMoltenVK.dylib
```

Installing this formula replaces the package; it does not prove a particular
already-running application's selected Vulkan driver. Restart that application
and verify its loaded library when comparing results.

## Private Metal interfaces

Every build sets **`MVK_USE_METAL_PRIVATE_API=1`**. No opt-in flag is needed.
The old `--with-metal-private-api` argument remains accepted for compatibility
with earlier install commands. There is no public-API-only build variant here.

This enables the SPI implementations already present in MoltenVK. It does not
by itself implement TensorOps convolution or the unfinished cooperative-matrix path.

## Requirements and build

- Apple Silicon / ARM64.
- macOS 26 (Tahoe) or newer.
- Full Xcode 26 or newer, selected and ready for command-line builds.
- Python 3 from the selected macOS developer tools for dependency preparation.

The formula builds from source in Release mode, with ARM64 architecture and a
macOS 26 deployment target. It uses the **MoltenVK** scheme in the source fork's
native **MoltenVK.xcworkspace**, the same workspace used for local Xcode development.
Its native targets build SPIRV-Cross, SPIRV-Tools, MoltenVK, and the shader converter
in one build graph; CMake is not needed.

It installs the dynamic/static libraries, XCFrameworks, shader converter, headers,
ICD manifest, and the native `MoltenVKProbe` executable. The normal MoltenVK package
layout is retained.

The source and dependency revisions are pinned. There is intentionally no
floating `--HEAD` build that could silently drop the selected patches or combine
unreviewed dependency tips. Update through the tap's published formula revisions:

```sh
brew update
brew upgrade DavidBrockmeier/tap/molten-vk
```

## Source and included patches

Formula version: **1.4.3-dev.20260918**, identifying an experimental development
snapshot, not an upstream 1.4.3 release.

Source: [DavidBrockmeier/MoltenVK](https://github.com/DavidBrockmeier/MoltenVK),
pinned to a commit in the formula. The fork includes the Xcode workspace, shared
build settings, native GPU probe, and these integrated fixes on top of
[upstream 4aaf714](https://github.com/KhronosGroup/MoltenVK/commit/4aaf714aa1b3e78e26ecfcefa9c75e9a576c500b).
The formula builds that source directly; it no longer carries an embedded patch.

| PR | Pinned head | Purpose |
|---|---|---|
| [#2819](https://github.com/KhronosGroup/MoltenVK/pull/2819) | `f17c4e0d3728b5c7fa18ec276fe5e5fa65577f52` | Compute/copy execution dependencies |
| [#2827](https://github.com/KhronosGroup/MoltenVK/pull/2827) | `2962af7a5d3d409a78bdd22a08adb2b5dab6913a` | Push-descriptor buffer-size metadata |
| [#2829](https://github.com/KhronosGroup/MoltenVK/pull/2829) | `062a23c615a0d82f4d377e72e159d7ef4052cc72` | Imported Metal texture ownership |
| [#2822](https://github.com/KhronosGroup/MoltenVK/pull/2822) | `fd8ea9dbb1963af3642d912bad651f018434c922` | Argument-buffer restoration after helper commands |

All seven dependency resources match the source's `ExternalRevisions` files:
SPIRV-Cross, SPIRV-Headers, SPIRV-Tools, Volk, Vulkan-Headers, Vulkan-Tools, and cereal.
These are correctness patches; a RIFE interpolation speedup has not been
demonstrated. Cooperative-matrix PR #2753 is excluded pending shader-translation
compatibility work. Building with a modern SDK alone does not implement a new
neural-compute path.

## Develop in Xcode

```sh
git clone https://github.com/DavidBrockmeier/MoltenVK.git
cd MoltenVK
python3 Scripts/prepare_dependencies.py
open MoltenVK.xcworkspace
```

Select **MoltenVK / My Mac**. Build with **⌘B**; **⌘R** builds Debug and runs
the probe against that build's dylib. Shared settings are in
`Config/MoltenVK.xcconfig`. `make` uses the same workspace in Release mode;
`make run` builds and runs Debug.

## Roll back to Homebrew core

```sh
brew reinstall homebrew/core/molten-vk --force-bottle
brew test homebrew/core/molten-vk
```

Use the fully qualified formula name to choose the source explicitly. Tapping
this repository alone does not replace the installed package; installation or
reinstallation does.

## Validation

CI replaces an installed Homebrew-core package with the same-named formula on
an ARM64 macOS 26 runner, with private Metal APIs enabled, and verifies
package ownership and linkage. Where the
runner exposes a Metal device, it also runs the formula test. A runner without
a Metal device reports that GPU execution was not checked. The formula test
checks the installed ICD path and public shader-converter headers, then runs
`MoltenVKProbe` against the exact installed dylib. The probe creates a Vulkan
device, fills a 4096-byte buffer on the GPU, waits for completion, and verifies
CPU readback.

Debug and Release workspace builds and their GPU transfer checks passed locally
with Xcode/SDK 27 on Apple M5 Max. This validates the build and driver execution;
RIFE throughput still needs an application benchmark.

## Licensing

Formula and repository documentation: BSD-2-Clause, with attribution to the
Homebrew formula on which this package is based. MoltenVK source and its
integrated runtime changes retain upstream Apache-2.0 licensing; dependencies retain their
own licenses. The formula installs MoltenVK's license with the package.
