#!/bin/zsh
set -euo pipefail

version="${1:-0.3.1}"
repository_root="$(cd "$(dirname "$0")/.." && pwd)"
output_directory="${OUTPUT_DIRECTORY:-${HOME}/Downloads/GodMode Mod Remote Control Release v${version}}"
output_dmg="${output_directory}/Mac-GodMode-Mod-Remote-Control-v${version}.dmg"
checksum_file="${output_dmg}.sha256"
signing_identity="${MAC_SIGNING_IDENTITY:-Developer ID Application: Matteo Zampieri (7HB6926XLK)}"
team_id="${DEVELOPMENT_TEAM:-7HB6926XLK}"
asc_key_id="${ASC_KEY_ID:-27G96FQG92}"
asc_issuer_id="${ASC_ISSUER_ID:-a5e9469e-76e9-440e-850b-5b4aef1f18b5}"
asc_key_filepath="${ASC_KEY_FILEPATH:?Set ASC_KEY_FILEPATH to an App Store Connect API key outside the repository.}"
work_directory="$(mktemp -d "${TMPDIR%/}/gta-remote-mac-release.XXXXXX")"
mount_directory="${work_directory}/mounted"
mounted="false"

cleanup() {
  if [[ "${mounted}" == "true" ]]; then
    hdiutil detach "${mount_directory}" >/dev/null 2>&1 || true
  fi
  case "${work_directory}" in
    "${TMPDIR%/}"/gta-remote-mac-release.*) /usr/bin/find "${work_directory}" -depth -delete 2>/dev/null || true ;;
  esac
}
trap cleanup EXIT

if [[ ! -f "${asc_key_filepath}" ]]; then
  print -u2 "App Store Connect API key not found: ${asc_key_filepath}"
  exit 1
fi
if [[ -e "${output_dmg}" || -e "${checksum_file}" ]]; then
  print -u2 "Release output already exists. Move it to Trash before rebuilding: ${output_dmg}"
  exit 1
fi

mkdir -p "${output_directory}" "${work_directory}/stage/.background" "${mount_directory}"

cd "${repository_root}"
xcodegen generate
xcodebuild \
  -project GTARemote.xcodeproj \
  -scheme GTABridge \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "${work_directory}/GodModeModRemoteControl.xcarchive" \
  archive \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="${signing_identity}" \
  DEVELOPMENT_TEAM="${team_id}"

archive_app="${work_directory}/GodModeModRemoteControl.xcarchive/Products/Applications/GTABridge.app"
staged_app="${work_directory}/stage/GodMode Mod Remote Control.app"
ditto "${archive_app}" "${staged_app}"

actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${staged_app}/Contents/Info.plist")"
if [[ "${actual_version}" != "${version}" ]]; then
  print -u2 "Archived app version ${actual_version} does not match requested version ${version}."
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "${staged_app}"
ditto -c -k --keepParent "${staged_app}" "${work_directory}/app-notary.zip"
xcrun notarytool submit "${work_directory}/app-notary.zip" \
  --key "${asc_key_filepath}" \
  --key-id "${asc_key_id}" \
  --issuer "${asc_issuer_id}" \
  --wait \
  --output-format json > "${work_directory}/app-notary.json"
if [[ "$(plutil -extract status raw "${work_directory}/app-notary.json")" != "Accepted" ]]; then
  print -u2 "Apple did not accept the app for notarization."
  exit 1
fi
xcrun stapler staple "${staged_app}"
xcrun stapler validate "${staged_app}"
spctl -a -vv "${staged_app}"

ditto "${repository_root}/docs/mac-start-here.html" "${work_directory}/stage/1. START HERE.html"
sips -s format png "${repository_root}/docs/install-background.svg" \
  --out "${work_directory}/stage/.background/install-background.png" >/dev/null

python3 -m venv "${work_directory}/venv"
"${work_directory}/venv/bin/python" -m pip install --disable-pip-version-check --quiet "dmgbuild==1.6.2"
GTA_REMOTE_DMG_STAGE="${work_directory}/stage" \
  "${work_directory}/venv/bin/python" -m dmgbuild \
  -s "${repository_root}/Scripts/mac-dmg-settings.py" \
  "GodMode Mod Remote Control" \
  "${work_directory}/release.dmg"

codesign --force --sign "${signing_identity}" --timestamp "${work_directory}/release.dmg"
codesign --verify --deep --strict --verbose=2 "${work_directory}/release.dmg"
xcrun notarytool submit "${work_directory}/release.dmg" \
  --key "${asc_key_filepath}" \
  --key-id "${asc_key_id}" \
  --issuer "${asc_issuer_id}" \
  --wait \
  --output-format json > "${work_directory}/dmg-notary.json"
if [[ "$(plutil -extract status raw "${work_directory}/dmg-notary.json")" != "Accepted" ]]; then
  print -u2 "Apple did not accept the DMG for notarization."
  exit 1
fi
xcrun stapler staple "${work_directory}/release.dmg"
xcrun stapler validate "${work_directory}/release.dmg"
hdiutil verify "${work_directory}/release.dmg"

hdiutil attach -readonly -nobrowse -mountpoint "${mount_directory}" "${work_directory}/release.dmg" >/dev/null
mounted="true"
test -d "${mount_directory}/GodMode Mod Remote Control.app"
test -f "${mount_directory}/1. START HERE.html"
test -L "${mount_directory}/Applications"
codesign --verify --deep --strict --verbose=2 "${mount_directory}/GodMode Mod Remote Control.app"
spctl -a -vv "${mount_directory}/GodMode Mod Remote Control.app"
hdiutil detach "${mount_directory}" >/dev/null
mounted="false"

ditto "${work_directory}/release.dmg" "${output_dmg}"
shasum -a 256 "${output_dmg}" | tee "${checksum_file}"
print "Mac release created and verified: ${output_dmg}"
