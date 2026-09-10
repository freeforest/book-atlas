#!/bin/bash
# Local, ad-hoc signed distribution. Never signs with Developer ID or publishes.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$project_root/dist}"
project_file="$project_root/BookAtlas.xcodeproj/project.pbxproj"
setting_root=objects.BA0000000000000000000411.buildSettings
version=$(/usr/bin/plutil -extract "$setting_root.MARKETING_VERSION" raw -o - "$project_file")
build_number=$(/usr/bin/plutil -extract "$setting_root.CURRENT_PROJECT_VERSION" raw -o - "$project_file")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid version'; exit 1; }
[[ "$build_number" =~ ^[0-9]+$ ]] || { echo 'Invalid build number'; exit 1; }
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
artifact="$output_dir/BookAtlas-$version.dmg"
[[ ! -e "$artifact" && ! -e "$artifact.sha256" ]] || {
    echo 'Artifact already exists. Use a new output directory; nothing was overwritten.'; exit 1;
}
package_work=$(mktemp -d "${TMPDIR:-/tmp}/bookatlas-package.XXXXXX")
echo "Build/package evidence: $package_work"
trap 'package_exit=$?; if [[ "$package_exit" != 0 ]]; then echo "Packaging stopped ($package_exit); evidence retained at $package_work"; fi' EXIT
set +e
xcodebuild build -project "$project_root/BookAtlas.xcodeproj" -scheme BookAtlas \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$package_work/DerivedData" \
    -resultBundlePath "$package_work/release.xcresult" \
    ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    > "$package_work/release.log" 2>&1
build_exit=$?
set -e
printf '%s\n' "$build_exit" > "$package_work/build-exit.txt"
if [[ "$build_exit" != 0 ]]; then
    echo "Build failed ($build_exit). See $package_work/release.log"; exit "$build_exit"
fi

app="$package_work/DerivedData/Build/Products/Release/BookAtlas.app"
plist="$app/Contents/Info.plist"
executable="$app/Contents/MacOS/BookAtlas"
require_info() {
    local actual
    actual=$(/usr/libexec/PlistBuddy -c "Print :$1" "$plist") || exit 1
    if [[ "$actual" != "$2" ]]; then echo "Unexpected app metadata: $1"; exit 1; fi
}
require_info CFBundleIdentifier io.github.freeforest.BookAtlas
require_info CFBundleShortVersionString "$version"
require_info CFBundleVersion "$build_number"
require_info CFBundleExecutable BookAtlas
require_info CFBundlePackageType APPL
require_info LSMinimumSystemVersion 26.0
require_info CFBundleIconFile AppIcon
require_info LSApplicationCategoryType public.app-category.reference
[[ -s "$app/Contents/Resources/AppIcon.icns" ]] || exit 1
/usr/bin/lipo "$executable" -verify_arch arm64 x86_64
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app" \
    > "$package_work/signature-verify.txt" 2>&1
/usr/bin/codesign -d --verbose=4 "$app" > "$package_work/signature.txt" 2>&1
/usr/bin/grep -q '^Signature=adhoc$' "$package_work/signature.txt"
/usr/bin/grep -q '^TeamIdentifier=not set$' "$package_work/signature.txt"
/usr/bin/grep -q 'flags=.*runtime' "$package_work/signature.txt"
for architecture in arm64 x86_64; do
    entitlement_file="$package_work/entitlements-$architecture.plist"
    /usr/bin/codesign -d --arch "$architecture" --entitlements :- "$app" \
        > "$entitlement_file" 2> "$package_work/entitlements-$architecture.log"
    /usr/bin/plutil -lint "$entitlement_file" > /dev/null
    for key in com.apple.security.app-sandbox com.apple.security.files.user-selected.read-write \
        com.apple.security.files.bookmarks.app-scope; do
        [[ "$(/usr/libexec/PlistBuddy -c "Print :$key" "$entitlement_file")" == true ]]
    done
    [[ "$(/usr/bin/grep -c '<key>' "$entitlement_file")" == 3 ]]
done
/usr/bin/otool -L "$executable" > "$package_work/dynamic-libraries.txt"
# Runtime links must resolve exclusively to OS libraries/frameworks.
/usr/bin/awk '/^[[:space:]]+[^[:space:]]/ {
    if ($1 !~ /^\/System\/Library\// && $1 !~ /^\/usr\/lib\//) bad=1
} END {exit bad}' "$package_work/dynamic-libraries.txt"

stage="$package_work/volume"
mkdir "$stage"
/usr/bin/ditto "$app" "$stage/BookAtlas.app"
/bin/ln -s /Applications "$stage/Applications"
/usr/bin/ditto "$project_root/docs/INSTALL.txt" "$stage/安装说明 - INSTALL.txt"
/usr/bin/ditto "$project_root/LICENSE" "$stage/LICENSE.txt"
/usr/bin/codesign --verify --deep --strict "$stage/BookAtlas.app"
# A simple read-only, compressed DMG. No Finder automation or external tools.
/usr/bin/hdiutil create -volname "BookAtlas $version" -srcfolder "$stage" \
    -fs HFS+ -format UDZO "$package_work/BookAtlas-$version.dmg" \
    > "$package_work/dmg-create.log" 2>&1
/usr/bin/hdiutil verify "$package_work/BookAtlas-$version.dmg" \
    > "$package_work/dmg-verify.log" 2>&1
# Publish locally only after all checks succeeded. Keep build evidence outside dist.
/bin/cp -n "$package_work/BookAtlas-$version.dmg" "$artifact"
/usr/bin/cmp -s "$package_work/BookAtlas-$version.dmg" "$artifact"
(cd "$output_dir" && /usr/bin/shasum -a 256 "BookAtlas-$version.dmg" > "BookAtlas-$version.dmg.sha256")
printf 'Ready for installation checks: %s\nSHA-256: %s\n' "$artifact" "$artifact.sha256"
echo 'Ad-hoc signed, not Developer ID signed or notarized. Not uploaded or published.'
