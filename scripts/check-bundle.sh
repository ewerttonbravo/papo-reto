#!/bin/bash
# Fails unless the .app loads its dylibs only from Contents/Frameworks or the system, and no rpath leaves the bundle.
set -euo pipefail

app="$(cd "${1:?usage: $0 <app>}" && pwd -P)"
exe_dir="$app/Contents/MacOS"
exe="$exe_dir/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")"
frameworks="$app/Contents/Frameworks"

# load_commands <image> <LC_...>: the whole path each matching load command names, spaces included.
load_commands() {
  otool -l "$1" | awk -v cmd="$2" '$1 == "cmd" && $2 ~ cmd { getline; getline; sub(/^ *[a-z]+ /, ""); sub(/ \(offset [0-9]+\)$/, ""); print }'
}

# rpaths <image>: its LC_RPATHs expanded.
rpaths() {
  local dir
  while IFS= read -r dir; do
    dir="${dir/#@loader_path/$(dirname "$1")}"
    echo "${dir/#@executable_path/$exe_dir}"
  done < <(load_commands "$1" '^LC_RPATH$')
}

failed=0
fail() { echo "$(basename "$image"): $1" >&2; failed=1; }

icon="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$app/Contents/Info.plist" 2>/dev/null || true)"
[ -n "$icon" ] && [ -f "$app/Contents/Resources/${icon%.icns}.icns" ] ||
  { echo "Info.plist names the icon '$icon', missing from Resources" >&2; failed=1; }

for image in "$exe" "$frameworks"/*.dylib; do
  [ -f "$image" ] || continue
  while IFS= read -r dir; do
    case "$dir" in
    "$app"/* | /usr/lib/*) ;;
    # The toolchain's Swift back-deploy dir: macOS 13+ has the runtime in /usr/lib/swift, searched first.
    */usr/lib/swift-[0-9]*/macosx) ;;
    *) fail "rpath $dir is outside the bundle" ;;
    esac
  done < <(rpaths "$image")

  # dyld falls back to the loading executable's rpaths.
  search=$( (rpaths "$image"; [ "$image" = "$exe" ] || rpaths "$exe") )
  while IFS= read -r dep; do
    case "$dep" in
    /usr/lib/* | /System/*) continue ;;
    @rpath/*) ;;
    *) fail "loads $dep, outside the bundle and the system"; continue ;;
    esac
    lib="${dep#@rpath/}" found=""
    while IFS= read -r dir; do
      [ -f "$dir/$lib" ] && { found="$(cd "$dir" && pwd -P)/$lib"; break; }
    done <<< "$search"
    [ "$found" = "$frameworks/$lib" ] || fail "loads $dep from ${found:-nowhere}, not from Contents/Frameworks"
  done < <(load_commands "$image" '^LC_(LOAD|LOAD_WEAK|REEXPORT)_DYLIB$')
done
exit $failed
