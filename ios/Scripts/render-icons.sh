#!/bin/bash
# Renders the SVG icon sources in ios/Icons into PNGs for the asset catalog.
# Requires: brew install librsvg (rsvg-convert)
set -euo pipefail

ICONS_DIR="$(cd "$(dirname "$0")/../Icons" && pwd)"
ASSETS_DIR="$(cd "$(dirname "$0")/../RuleTheWorld/Resource/Assets.xcassets" && pwd)"

# name:size
render() {
    local svg="$1" name="$2" width="$3" height="$4"
    rsvg-convert -w "$width" -h "$height" "$ICONS_DIR/$svg" -o "$ASSETS_DIR/$name.imageset/$name.png"
    echo "rendered $svg -> $name.imageset/${name}.png"
}

render onboarding-explore.svg OnboardingExplore 1170 2532
render onboarding-capture.svg OnboardingCapture 1170 2532
render onboarding-powerup.svg OnboardingPowerUp 1170 2532
