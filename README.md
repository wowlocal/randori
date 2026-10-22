# Randori

A native Swift engine for 2D fighting games in the **LF2 2.0a data format**:
object and frame DAT files, bitmap sheets, WAV sounds, stages and the rest of
what *Little Fighter 2* version 2.0a reads. It runs a game's whole loop,
including loading, physics, combat, the character AI, stage and tournament
modes, menus, recordings and networking. Hosts are included for macOS (AppKit),
headless runs, SDL3 (Linux, Windows), iOS and tvOS (UIKit), Android and the
browser (WebAssembly).

## Where it comes from

The engine was rebuilt instruction by instruction from `lf2.exe` of LF2 2.0a,
as used by the fan game *Naruto: The Setting Dawn* (NTSD) 2.4, and it was checked
against that executable's behaviour piece by piece. The work was done in the
[NTSD 2.4 native port](https://github.com/wowlocal/ntsd-2.4); its
`exp/engine-split` branch uses this repository as the `engine/` submodule.

- **Default rules.** The engine's default rules are LF2 2.0a's
  (`OriginalGameRules.lf2`), including the object IDs the original code tests
  and the computer players' per-character routines.
- **NTSD 2.4's extensions.** NTSD 2.4 adds a small `lib.dll` that patches twelve
  places in the executable. Its extensions are an optional part of a game's
  rules (`OriginalGameRules.library`).
- **Application sessions without the extensions.** The application layer
  (menus, loading, matches) is modelled so far only with the extensions. A
  game without them stops with the typed error `OriginalLibData.Required`
  wherever a path without them is not modelled yet.

## No game content

This repository contains no game data, artwork, sound or music. A game
supplies its content, its content identity and its rules. The tests run on a
synthetic content pack that is generated in code (`Tests/RandoriTests/Synthetic`).

## Building

The engine needs Swift 6 and macOS 14 or later, or Linux.

```sh
swift build
swift test
```

Some targets are added only when their switch is set in the environment:

| Switch | What it adds or changes |
| --- | --- |
| `RANDORI_PORTABLE=1` | Leaves out the AppKit targets (needed for cross builds from macOS). |
| `RANDORI_SDL=1` | Adds the SDL3 host. Set `RANDORI_SDL_PREFIX` to the SDL3 install. |
| `RANDORI_FREETYPE_PREFIX` | Adds FreeType text for the SDL and Android hosts. |
| `RANDORI_WEB=1` | Adds the browser host, for the `wasm32-unknown-wasip1` target. |
| `RANDORI_IOS=1` | Adds the UIKit host. |
| `RANDORI_ANDROID=1` | Adds the Android host. |
| `RANDORI_UNCHECKED_EXCLUSIVITY=1` | Release builds without dynamic exclusivity checks. |

The older names (`NTSD_*`) are still accepted.

## Using it as a dependency

The package uses `unsafeFlags`, for example for cross-module optimisation in
release builds. SwiftPM therefore accepts it as a root package, a local path,
or a branch or revision dependency. It does not accept it as a versioned
dependency.

## Credits and notices

*Little Fighter 2* is by Marti Wong and Starsky Wong ([lf2.net](https://www.lf2.net)).
*Little Fighter 2 Remastered* is a commercial game by Little Fighter Co Pty Ltd.
*Naruto: The Setting Dawn* is by its authors. This project is not affiliated
with or endorsed by any of them.

The engine includes two pieces of vendored code, each under its own licence
(see [NOTICE](NOTICE)):

- zlib 1.1.4, by Jean-loup Gailly and Mark Adler, under the zlib licence;
- Apple's ALAC decoder, under the Apache License 2.0.

## Licence

The project's own code is under the [Apache License 2.0](LICENSE).
