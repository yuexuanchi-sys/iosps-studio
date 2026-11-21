#!/bin/bash
set -euo pipefail

output="$(mkdir -p "${1:?Provide an evidence directory}" && cd "$1" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
spike="$(cd "$(dirname "$0")" && pwd)"
revision=722178133bc8d82592ddc093382511e3e8e591b2
checksum=6295c9db25b3ff3e4bf0985028841254a7a9c2fbd4218c9a30cd4c90ffba51ae

curl --fail --silent --show-error --location --retry 3 \
  "https://codeload.github.com/JesusMonjeGonzalez/NovaCut/zip/$revision" --output "$work/source.zip"
printf '%s  %s\n' "$checksum" "$work/source.zip" | shasum -a 256 -c -
upstream="NovaCut-$revision"
sources=(Timeline Mezclador Sonoridad Transcript Composicion LUTs Proyecto Exportacion)
for name in "${sources[@]}"; do
  unzip -p "$work/source.zip" "$upstream/src/ui/$name.swift" > "$work/$name.swift"
done
unzip -p "$work/source.zip" "$upstream/LICENSE" > "$output/LICENSE-NovaCut.txt"
unzip -p "$work/source.zip" "$upstream/src/ui/App.swift" |
  sed -n '/^enum EditorError: LocalizedError {$/,/^}$/p' > "$work/EditorError.swift"
patch "$work/Composicion.swift" "$spike/swift6.patch"

xcrun swiftc -swift-version 6 -strict-concurrency=complete -target arm64-apple-macos14.0 \
  "$work/"*.swift "$spike/main.swift" -o "$work/verify"
xcrun vtool -show-build "$work/verify" | tee "$output/build-target.txt"
grep -Eq 'minos 14\.0([[:space:]]|$)' "$output/build-target.txt"
test "$(lipo -archs "$work/verify")" = arm64
otool -L "$work/verify" | tee "$output/linked-libraries.txt"
/usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network*)' \
  "$work/verify" "$output" | tee "$output/verification.txt"
(cd "$output" && shasum -a 256 source-a.mov source-b.mp4 project.editorcito edited.mp4 > SHA256SUMS.txt)
