# Homebrew tap

A same-name replacement formula for **`molten-vk`**. This tap deliberately
collides with `homebrew/core/molten-vk`: it uses the same Cellar name, opt link,
library names, and Vulkan driver-manifest location. It is not keg-only and is not
a separately named variant.

## Replace an existing installation

Quit applications using the driver before switching. With current Homebrew:

```sh
brew tap DavidBrockmeier/tap
brew reinstall DavidBrockmeier/tap/molten-vk
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

On Homebrew versions that request tap trust, trust this formula specifically:

```sh
brew trust --formula DavidBrockmeier/tap/molten-vk
```

The normal Apple Silicon library paths remain:

```text
/opt/homebrew/opt/molten-vk/lib/libMoltenVK.dylib
/opt/homebrew/lib/libMoltenVK.dylib
```

Installing this formula replaces the package; it does not prove a particular
already-running application's selected Vulkan driver. Restart that application
and verify its loaded library when comparing results.

## Optional private Metal interfaces

```sh
brew reinstall DavidBrockmeier/tap/molten-vk --with-metal-private-api
```

These interfaces implement graphics compatibility features. They do not enable
M5 Neural Accelerators, TensorOps convolution, or cooperative-matrix support.
The default build leaves them disabled. To explicitly return to the default:

```sh
brew reinstall DavidBrockmeier/tap/molten-vk --without-metal-private-api
```

## Requirements and build

- Apple Silicon / ARM64.
- macOS 26 (Tahoe) or newer.
- Full Xcode 26 or newer, selected and ready for command-line builds.
- Homebrew installs the declared CMake build dependency.

The formula builds from source in Release mode, with ARM64 architecture and a
macOS 26 deployment target. It installs the dynamic/static libraries,
XCFrameworks, shader converter, headers, and ICD manifest, following the standard
MoltenVK package layout.

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

Base source: [MoltenVK 4aaf714](https://github.com/KhronosGroup/MoltenVK/commit/4aaf714aa1b3e78e26ecfcefa9c75e9a576c500b).
The formula embeds the integrated patch rather than downloading mutable PR diffs.

| PR | Pinned head | Purpose |
|---|---|---|
| [#2819](https://github.com/KhronosGroup/MoltenVK/pull/2819) | `f17c4e0d3728b5c7fa18ec276fe5e5fa65577f52` | Compute/copy execution dependencies |
| [#2827](https://github.com/KhronosGroup/MoltenVK/pull/2827) | `2962af7a5d3d409a78bdd22a08adb2b5dab6913a` | Push-descriptor buffer-size metadata |
| [#2829](https://github.com/KhronosGroup/MoltenVK/pull/2829) | `062a23c615a0d82f4d377e72e159d7ef4052cc72` | Imported Metal texture ownership |
| [#2822](https://github.com/KhronosGroup/MoltenVK/pull/2822) | `fd8ea9dbb1963af3642d912bad651f018434c922` | Argument-buffer restoration after helper commands |

All six dependency resources match the base revision's `ExternalRevisions`
files. These are correctness patches; a RIFE interpolation speedup has not been
demonstrated. Cooperative-matrix PR #2753 is excluded pending shader-translation
compatibility work. Building with a modern SDK alone does not implement a new
neural-compute path.

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
an ARM64 macOS 26 runner, with and without the private-API option, and verifies
package ownership and linkage. Where the
runner exposes a Metal device, it also runs the formula test. A runner without
a Metal device reports that GPU initialization was not checked. The formula test
checks its installed ICD path, creates a Vulkan instance, enumerates a GPU, and
destroys the instance. It is an initialization test, not an interpolation
benchmark or a complete Vulkan CTS run.

The matching source/patch set was also built locally with Xcode/SDK 27 and
initialized on Apple M5 Max. That result does not establish application stability
or performance for every consumer of the replacement library.

## Licensing

Formula and repository documentation: BSD-2-Clause, with attribution to the
Homebrew formula on which this package is based. MoltenVK source and its embedded
runtime patch retain upstream Apache-2.0 licensing; dependencies retain their
own licenses. The formula installs MoltenVK's license with the package.
