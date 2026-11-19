#!/bin/bash
# Fails unless every @rpath dylib the .app loads resolves, in dyld's rpath order, to a file in Contents/Frameworks.
set -euo pipefail

app="$(cd "${1:?usage: $0 <app>}" && pwd -P)"
exe_dir="$app/Contents/MacOS"
exe="$exe_dir/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")"
frameworks="$app/Contents/Frameworks"

# load_commands <image> <LC_...>: the path each matching load command names.
load_commands() { otool -l "$1" | awk -v cmd="$2" '$1 == "cmd" && $2 ~ cmd { getline; getline; print $2 }'; }

# rpaths <image>: its LC_RPATHs expanded; dyld then falls back to the loading executable's.
rpaths() {
  load_commands "$1" '^LC_RPATH$' | sed -e "s|^@loader_path|$(dirname "$1")|" -e "s|^@executable_path|$exe_dir|"
}

failed=0
for image in "$exe" "$frameworks"/*.dylib; do
  [ -f "$image" ] || continue
  search=$( (rpaths "$image"; [ "$image" = "$exe" ] || rpaths "$exe") )
  while read -r dep; do
    lib="${dep#@rpath/}" found=""
    while read -r dir; do
      [ -f "$dir/$lib" ] && { found="$(cd "$dir" && pwd -P)/$lib"; break; }
    done <<< "$search"
    if [ "$found" != "$frameworks/$lib" ]; then
      echo "$(basename "$image") loads $dep from ${found:-nowhere}, not from Contents/Frameworks" >&2
      failed=1
    fi
  done < <(load_commands "$image" '^LC_(LOAD|LOAD_WEAK|REEXPORT)_DYLIB$' | grep '^@rpath/' || true)
done
exit $failed
