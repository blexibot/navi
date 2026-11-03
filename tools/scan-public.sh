#!/usr/bin/env bash
# scan-public.sh: fail if a tree contains anything that must not go public.
#
# Usage:
#   tools/scan-public.sh [options] [DIR]          (DIR defaults to the repo this script lives in)
#
# Options:
#   --git-tracked        scan only files tracked by git in DIR (default: every file under DIR except .git/)
#   --exclude PREFIX     skip paths starting with PREFIX (relative to DIR); may be repeated
#   --counts-only        print only per-category counts, never file names or lines
#   --show               also print the matching text (local use only; never paste it anywhere)
#   --history            also check git history: commit metadata and messages, plus gitleaks over all commits
#   -h, --help           this text
#
# Checks (each is a category in the output):
#   secrets      gitleaks (if installed) plus a built-in list of common key shapes
#   private_ip   10/8, 172.16/12, 192.168/16 and 100.64/10 (Tailscale CGNAT) addresses
#   tailnet      *.ts.net names and tailnet ids
#   email        any e-mail address outside example/test domains and the GitHub/Anthropic noreply addresses
#   home_path    absolute home paths (/home/<user>, /Users/<user>)
#   serial       device serial numbers after "serial", "adb -s" or ANDROID_SERIAL
#   mac_address  hardware MAC addresses
#   denylist     every term in the private denylist (whole word, any case), in file contents AND file paths
#
# The denylist is private and never lives in git:
#   ${NAVI_PUBLIC_DENYLIST:-$HOME/.config/navi-public/denylist.txt}   (one term per line, # comments)
#
# Exit: 0 clean, 1 findings, 2 setup or usage error.
# Portable: bash 3.2+, POSIX tools, GNU or BSD grep/tar (Linux and macOS).

set -u
LC_ALL=C
export LC_ALL

git_tracked=0; counts_only=0; show=0; history=0
excludes=()
dir=""

usage() { sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --git-tracked) git_tracked=1 ;;
    --exclude) shift; [ $# -gt 0 ] || { echo "scan-public: --exclude needs a value" >&2; exit 2; }; excludes+=("$1") ;;
    --counts-only) counts_only=1 ;;
    --show) show=1 ;;
    --history) history=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "scan-public: unknown option $1" >&2; exit 2 ;;
    *) dir="$1" ;;
  esac
  shift
done

if [ -z "$dir" ]; then
  dir="$(cd "$(dirname "$0")/.." && pwd)"
fi
[ -d "$dir" ] || { echo "scan-public: not a directory: $dir" >&2; exit 2; }
dir="$(cd "$dir" && pwd)"

denylist="${NAVI_PUBLIC_DENYLIST:-$HOME/.config/navi-public/denylist.txt}"
[ -r "$denylist" ] || { echo "scan-public: denylist not readable: $denylist" >&2; exit 2; }

work="$(mktemp -d "${TMPDIR:-/tmp}/scan-public.XXXXXX")" || exit 2
chmod 700 "$work"
trap 'rm -rf "$work"' EXIT

# Terms, comments and blank lines stripped.
grep -v '^[[:space:]]*#' "$denylist" | sed 's/[[:space:]]*$//' | grep -v '^$' > "$work/terms" || true
[ -s "$work/terms" ] || { echo "scan-public: denylist has no terms" >&2; exit 2; }

# ---- file list (paths relative to $dir, NUL-separated)
cd "$dir" || exit 2
if [ "$git_tracked" -eq 1 ]; then
  git -C "$dir" ls-files -z > "$work/all.z" || { echo "scan-public: git ls-files failed" >&2; exit 2; }
else
  find . -path ./.git -prune -o -type f -print0 | sed -z 's#^\./##' > "$work/all.z" 2>/dev/null \
    || { find . -path ./.git -prune -o -type f -print | sed 's#^\./##' | tr '\n' '\0' > "$work/all.z"; }
fi

# Apply excludes and drop this script's own denylist-free pattern text from nothing: the script is scanned too.
tr '\0' '\n' < "$work/all.z" > "$work/all.txt"
cp "$work/all.txt" "$work/list.txt"
for p in ${excludes[@]+"${excludes[@]}"}; do
  awk -v p="$p" 'index($0, p) != 1' "$work/list.txt" > "$work/list.tmp" && mv "$work/list.tmp" "$work/list.txt"
done
# Skip files that vanished (deleted but still tracked) and symlinks.
: > "$work/files.txt"
while IFS= read -r f; do
  [ -f "$f" ] && [ ! -L "$f" ] && printf '%s\n' "$f" >> "$work/files.txt"
done < "$work/list.txt"
tr '\n' '\0' < "$work/files.txt" > "$work/files.z"
nfiles=$(wc -l < "$work/files.txt" | tr -d ' ')

total=0
report() { # category, file-with-"path:line:text" lines
  local cat="$1" hits="$2" n m
  n=$(wc -l < "$hits" | tr -d ' ')
  m=$(cut -d: -f1 "$hits" | sort -u | grep -c . || true)
  total=$((total + n))
  if [ "$counts_only" -eq 1 ]; then
    printf '%-12s %6d matches in %5d files\n' "$cat" "$n" "$m"
  elif [ "$n" -gt 0 ]; then
    printf '== %s: %d matches in %d files\n' "$cat" "$n" "$m"
    if [ "$show" -eq 1 ]; then cat "$hits"; else cut -d: -f1,2 "$hits"; fi
  fi
}

scan() { # category, grep options..., pattern ; result lines path:line:text in $work/<category>
  local cat="$1"; shift
  if [ "$nfiles" -gt 0 ]; then
    xargs -0 grep -HnI "$@" < "$work/files.z" > "$work/$cat" 2>/dev/null || true
  else
    : > "$work/$cat"
  fi
}

# gitleaks JSON report -> "path:line:gitleaks <rule>" lines (one key per line in the report, any order).
gl_parse() {
  awk -v strip="$2" '
    /"RuleID":/    { r=$0; sub(/.*"RuleID": *"/,"",r); sub(/".*/,"",r) }
    /"StartLine":/ { l=$0; sub(/.*"StartLine": */,"",l); sub(/[^0-9].*/,"",l) }
    /"File":/      { f=$0; sub(/.*"File": *"/,"",f); sub(/",? *$/,"",f); if (strip != "" && index(f,strip)==1) f=substr(f,length(strip)+1) }
    /^ *}/         { if (r != "") print f ":" l ":gitleaks " r; r=""; l=""; f="" }
  ' "$1"
}

# ---- secrets
: > "$work/secrets"
scan secrets_builtin -E -e 'AKIA[0-9A-Z]{16}' -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' -e 'gh[pousr]_[A-Za-z0-9]{36}' \
  -e 'github_pat_[A-Za-z0-9_]{20,}' -e 'xox[abprs]-[A-Za-z0-9-]{10,}' -e 'sk-ant-[A-Za-z0-9_-]{20,}' \
  -e 'sk-[A-Za-z0-9]{32,}' -e 'AIza[0-9A-Za-z_-]{35}' -e '[0-9]{8,10}:AA[0-9A-Za-z_-]{33}'
cat "$work/secrets_builtin" >> "$work/secrets"
if command -v gitleaks >/dev/null 2>&1; then
  mkdir -p "$work/copy"
  if [ "$nfiles" -gt 0 ]; then
    tar -cf - --null -T "$work/files.z" 2>/dev/null | tar -xf - -C "$work/copy" 2>/dev/null
  fi
  gitleaks dir "$work/copy" --no-banner --redact --exit-code 0 --report-format json \
    --report-path "$work/gl.json" >/dev/null 2>&1
  [ -s "$work/gl.json" ] && gl_parse "$work/gl.json" "$work/copy/" >> "$work/secrets"
  gl_note="gitleaks $(gitleaks version 2>/dev/null)"
else
  gl_note="gitleaks not installed: built-in key patterns only"
fi
report secrets "$work/secrets"

# ---- private addresses
scan private_ip -E -e '(^|[^0-9.])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$)'
report private_ip "$work/private_ip"

scan tailnet -E -i -e '[a-z0-9-]+\.ts\.net' -e '(^|[^a-z0-9])tail[0-9a-f]{6}([^a-z0-9]|$)'
report tailnet "$work/tailnet"

# ---- e-mail addresses (allowlisted domains removed)
scan email_raw -E -o -e '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
grep -v -i -E '@([a-z0-9.-]+\.)?example(\.(com|org|net))?$|@[a-z0-9.-]+\.(invalid|test|example|localhost)$|@users\.noreply\.github\.com$|^[^:]*:[0-9]+:noreply@anthropic\.com$|\.(service|scope|socket|target|timer|mount|slice)$' \
  "$work/email_raw" > "$work/email" || true
report email "$work/email"

scan home_path -E -e '/(home|Users)/[A-Za-z0-9._-]+'
report home_path "$work/home_path"

scan serial -E -i -e '(serial([ _-]?(no|number))?|adb -s|android_serial)[ :=#"'"'"']+[A-Z]{0,10}[0-9][A-Z0-9]{4,}'
report serial "$work/serial"

scan mac_address -E -e '(^|[^0-9A-Fa-f:])([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}([^0-9A-Fa-f:]|$)'
report mac_address "$work/mac_address"

# ---- denylist: contents and paths
scan denylist -i -w -F -f "$work/terms"
grep -i -w -F -f "$work/terms" "$work/files.txt" | sed 's/$/:0:(path)/' >> "$work/denylist" || true
report denylist "$work/denylist"

# ---- history (optional)
if [ "$history" -eq 1 ] && git -C "$dir" rev-parse --verify -q HEAD >/dev/null 2>&1; then
  git -C "$dir" log --all --format='%H%n%an <%ae>%n%cn <%ce>%n%B' > "$work/log.txt"
  : > "$work/history"
  grep -n -o -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$work/log.txt" \
    | grep -v -i -E ':(noreply@anthropic\.com|[A-Za-z0-9._+-]+@users\.noreply\.github\.com)$' \
    | sed 's/^/git-log:/' >> "$work/history" || true
  grep -n -i -w -F -f "$work/terms" "$work/log.txt" | sed 's/^/git-log:/' >> "$work/history" || true
  if command -v gitleaks >/dev/null 2>&1; then
    gitleaks git "$dir" --no-banner --redact --exit-code 0 --report-format json \
      --report-path "$work/glh.json" >/dev/null 2>&1
    [ -s "$work/glh.json" ] && gl_parse "$work/glh.json" "" | sed 's/^/git-history:/' >> "$work/history"
  fi
  report history "$work/history"
fi

echo "scanned $nfiles files in $dir (${gl_note}; denylist $(wc -l < "$work/terms" | tr -d ' ') terms)"
if [ "$total" -gt 0 ]; then
  echo "FAIL: $total findings"
  exit 1
fi
echo "PASS: nothing found"
exit 0
