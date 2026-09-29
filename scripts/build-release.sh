#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
repo_root="$PWD"
release_tag="${1:?Usage: bash scripts/build-release.sh v1.2.4[-beta.1]}"
if [[ ! "$release_tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)(-[A-Za-z0-9]+([.-][A-Za-z0-9]+)*)?$ ]]; then
  echo "Expected a version tag such as v1.2.4 or v1.2.4-beta.1" >&2
  exit 1
fi
app_version="${BASH_REMATCH[1]}"
build_number="${BUILD_NUMBER:-1}"
if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "BUILD_NUMBER must be a positive integer" >&2
  exit 1
fi

derived_data="$repo_root/.build/ReleaseDerivedData"
output_dir="$repo_root/.build/release"
mkdir -p "$output_dir"
staging_dir="$(mktemp -d "$repo_root/.build/release-staging.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT

# Override the upstream developer team; no certificate or provisioning secret is
# required. Xcode also signs the embedded code with the ad-hoc identity.
xcodebuild \
  -project Overview.xcodeproj \
  -scheme Overview \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_data" \
  -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipMacroValidation \
  -skipPackagePluginValidation \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  ENABLE_HARDENED_RUNTIME=NO \
  MARKETING_VERSION="$app_version" \
  CURRENT_PROJECT_VERSION="$build_number" \
  build

app_path="$staging_dir/Overview.app"
ditto "$derived_data/Build/Products/Release/Overview.app" "$app_path"
test -x "$app_path/Contents/MacOS/Overview"
lipo "$app_path/Contents/MacOS/Overview" -verify_arch arm64 x86_64
codesign --verify --deep --strict --verbose=2 "$app_path"

asset_name="Overview-${release_tag}-macOS-universal"
ln -s /Applications "$staging_dir/Applications"
hdiutil create -volname Overview -srcfolder "$staging_dir" \
  -format UDZO -ov "$output_dir/$asset_name.dmg"
hdiutil verify "$output_dir/$asset_name.dmg"

echo "Release DMG created at $output_dir/$asset_name.dmg"
