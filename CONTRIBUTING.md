# Contributing

Thanks for helping! Bug reports, macOS-compatibility fixes, translations and documentation improvements are all welcome.

## Reporting a bug

Open an issue with your macOS version, Mac model, display setup and what you expected. For switching or Mission Control problems, include whether Accessibility is granted. The [troubleshooting guide](docs/troubleshooting.md) lists the useful commands.

## Development setup

```sh
git clone https://github.com/jakubfabrici/macspacename.git
cd macspacename
swift build && swift test     # or: xed .  to open in Xcode
make run                      # builds the .app bundle and launches it
```

Requirements: macOS 13+, Xcode 15+ (Swift 5.9). There is no Xcode project; `Package.swift` is the project.

## Guidelines

* Keep private API usage inside `Sources/MacSpaceName/System/PrivateAPI.swift` and resolve symbols with `dlsym`, so a missing symbol degrades the feature instead of crashing the app.
* Logic that does not need AppKit goes into `MacSpaceNameCore` with a unit test.
* New persisted fields must decode with a default (`decodeIfPresent`) so existing `config.json` files keep working.
* Match the existing style: small files, one responsibility each, `@MainActor` app classes, no Combine chains where a selector will do.
* Document user-facing changes in `CHANGELOG.md` and, if relevant, `docs/features.md`.

## Pull requests

1. Branch from `main`.
2. `swift test` must pass; CI builds the app bundle on a macOS runner.
3. Describe what changed and how you tested it (which macOS version, displays).

## Releasing

Tag a commit `vX.Y.Z` and push the tag. The Release workflow builds a universal `.app`, zips it, computes a SHA-256 and publishes a GitHub release with auto-generated notes.
