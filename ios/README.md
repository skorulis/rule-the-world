# RuleTheWorld

iOS app built from the ios-2026 template.

## Verification

```bash
swiftgen
xcodebuild -scheme RuleTheWorld -configuration Debug build
swiftlint --fix --strict
```

See [Architecture.md](Architecture.md) for architectural decisions.

## Art assets

Icons and onboarding backgrounds are hand-authored SVGs in `Icons/`, rasterized
into `RuleTheWorld/Resource/Assets.xcassets` with `Scripts/render-icons.sh`
(requires `rsvg-convert`, e.g. `brew install librsvg`). Run `swiftgen` afterwards
to regenerate `XCAssets+Generated.swift`.
