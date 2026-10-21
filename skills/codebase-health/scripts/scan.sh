#!/bin/bash
# Collect structural health signals for a Git repository.
# Usage: scan.sh [path] [max-lines] [max-files-per-dir]
# Every section is a lead to verify, not a finding.

set -euo pipefail

SCOPE="${1:-.}"
MAX_LINES="${2:-350}"
MAX_DIR_FILES="${3:-20}"

echo '$ pwd'
pwd

if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo 'Error: run this script inside a Git working tree.' >&2
  exit 1
fi
SCOPE=$(cd "$SCOPE" && pwd)
cd "$REPO_ROOT"
SCOPE="${SCOPE#"$REPO_ROOT"}"
SCOPE="${SCOPE#/}"
SCOPE="${SCOPE:-.}"

echo ''
echo "repository root: $REPO_ROOT"
echo "scope: $SCOPE"
echo "thresholds: files > $MAX_LINES lines, directories >= $MAX_DIR_FILES files"

# Generated, vendored and lock files are excluded from code-level checks.
EXCLUDE_RE='(^|/)(node_modules|dist|build|out|coverage|\.next|\.nuxt|\.svelte-kit|\.output|\.turbo|\.vercel|storybook-static|vendor|generated|__generated__|__snapshots__)/|\.min\.(js|css)$|\.map$|\.snap$|\.d\.ts$|(^|/)(package-lock\.json|npm-shrinkwrap\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?)$'
SOURCE_RE='\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|vue|svelte|astro|css|scss|sass|less|html|py|rb|go|rs|java|kt|swift|php|cs|sh)$'
SCRIPT_RE='\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|vue|svelte|astro)$'
TEST_RE='(\.|_)(test|spec|e2e|cy)\.[cm]?[jt]sx?$|(^|/)(__tests__|e2e|cypress)/'
I18N_RE='(^|/)(locales?|i18n|translations?|lang|messages)/'

section() {
  echo ''
  echo "## $1"
}

# Tracked plus untracked, non-ignored files that still exist.
all_files() {
  git -c core.quotepath=off ls-files --cached --others --exclude-standard -- "$SCOPE" |
    while IFS= read -r f; do [ -f "$f" ] && echo "$f"; done
}

FILES=$(mktemp)
trap 'rm -f "$FILES"' EXIT
all_files >"$FILES"

files() { grep -Ev "$EXCLUDE_RE" "$FILES" || true; }
matching() { files | grep -E "$1" || true; }
source_files() { matching "$SOURCE_RE"; }
app_files() { matching "$SCRIPT_RE" | grep -Ev "$TEST_RE" || true; }
test_files() { matching "$SCRIPT_RE" | grep -E "$TEST_RE" || true; }

# Print "file:line:match" for a pattern across a file list read from stdin.
grep_list() {
  tr '\n' '\0' | xargs -0 grep -nE "$1" 2>/dev/null | head -n "${2:-60}" || true
}

# Print "count  file" for files with at least one match, highest first.
count_list() {
  tr '\n' '\0' | xargs -0 grep -cE "$1" 2>/dev/null |
    awk -F: '$NF > 0 { n = $NF; sub(/:[0-9]+$/, ""); printf "%5d  %s\n", n, $0 }' |
    sort -rn | head -n "${2:-30}" || true
}

section 'Overview'
echo "files in scope: $(wc -l <"$FILES" | tr -d ' ')"
echo "source files (excluding generated): $(source_files | wc -l | tr -d ' ')"
echo ''
echo 'files per top-level entry:'
files | awk -F/ '{ print (NF > 1 ? $1 "/" : $1) }' | sort | uniq -c | sort -rn | head -30

section 'Package manifests'
MANIFESTS=$(files | grep -E '(^|/)package\.json$' || true)
if [ -z "$MANIFESTS" ]; then
  echo '(none)'
elif command -v node >/dev/null 2>&1; then
  echo "$MANIFESTS" | while IFS= read -r m; do
    node -e '
      const fs = require("fs");
      const file = process.argv[1];
      let p;
      try { p = JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { console.log(`\n### ${file}\ninvalid JSON: ${e.message}`); process.exit(0); }
      const count = (k) => Object.keys(p[k] || {}).length;
      console.log(`\n### ${file}`);
      for (const k of ["name", "type", "packageManager", "engines", "volta", "workspaces", "overrides", "resolutions"]) {
        if (p[k] !== undefined) console.log(`${k}: ${JSON.stringify(p[k])}`);
      }
      console.log(`dependencies: ${count("dependencies")}, devDependencies: ${count("devDependencies")}, peerDependencies: ${count("peerDependencies")}`);
      console.log("scripts:");
      for (const [k, v] of Object.entries(p.scripts || {})) console.log(`  ${k}: ${v}`);
    ' "$m"
  done
else
  echo 'node not found; read these manifests directly:'
  echo "$MANIFESTS"
fi

section 'Environment and package manager files'
grep -E '(^|/)(package-lock\.json|npm-shrinkwrap\.json|pnpm-lock\.yaml|pnpm-workspace\.yaml|yarn\.lock|bun\.lockb?|\.nvmrc|\.node-version|\.tool-versions|\.?mise\.toml|\.npmrc|\.yarnrc(\.yml)?|bunfig\.toml|\.yarn/releases/[^/]+|deno\.jsonc?|Dockerfile[^/]*|docker-compose[^/]*|\.devcontainer/[^/]+|\.env[^/]*)$' "$FILES" | grep -v '/node_modules/' || echo '(none)'
echo ''
for f in .nvmrc .node-version; do
  [ -f "$f" ] && echo "$f: $(tr -d '[:space:]' <"$f")"
done
echo "local tools: node $(node -v 2>/dev/null || echo '-'), npm $(npm -v 2>/dev/null || echo '-'), pnpm $(pnpm -v 2>/dev/null || echo '-'), yarn $(yarn -v 2>/dev/null || echo '-'), bun $(bun -v 2>/dev/null || echo '-')"
echo ''
echo 'tracked env files (should usually be examples only):'
git -c core.quotepath=off ls-files -- "$SCOPE" | grep -E '(^|/)\.env' | grep -Ev '\.(example|sample|template|dist|defaults)$' || echo '(none)'

section 'CI/CD and automation files'
grep -E '(^|/)(\.github/workflows/[^/]+|\.github/actions/.+|\.github/dependabot\.ya?ml|\.gitlab-ci\.yml|\.circleci/.+|azure-pipelines\.ya?ml|bitbucket-pipelines\.yml|Jenkinsfile|renovate\.json5?|\.renovaterc[^/]*|vercel\.json|netlify\.toml|\.husky/[^_][^/]*|lefthook\.ya?ml|\.lintstagedrc[^/]*|lint-staged\.config\.[^/]+)$' "$FILES" || echo '(none)'
if ls .github/workflows/*.y*ml >/dev/null 2>&1; then
  echo ''
  echo 'action references (check for outdated majors and unpinned refs):'
  grep -hoE 'uses:[[:space:]]*[^[:space:]#]+' .github/workflows/*.y*ml | sed -E 's/uses:[[:space:]]*//' | sort | uniq -c | sort -rn
  echo ''
  echo 'workflow features (missing lines are leads, not proof):'
  for w in .github/workflows/*.y*ml; do
    printf '%s:' "$w"
    grep -qE '^concurrency:|^[[:space:]]+concurrency:' "$w" && printf ' concurrency'
    grep -qE 'cancel-in-progress' "$w" && printf ' cancel-in-progress'
    grep -qE 'cache:|actions/cache' "$w" && printf ' cache'
    grep -qE 'timeout-minutes' "$w" && printf ' timeout'
    grep -qE 'paths(-ignore)?:' "$w" && printf ' path-filters'
    grep -E '(npm|pnpm|yarn|bun) (install|i)([[:space:]]|$)' "$w" | grep -qvE 'frozen-lockfile|immutable' && printf ' install-without-frozen-lockfile'
    grep -qE 'node-version:' "$w" && printf ' hardcoded-node-version'
    grep -qE 'node-version-file' "$w" && printf ' node-version-file'
    echo ''
  done
fi

section 'Tool configuration files'
grep -Ev '(^|/)node_modules/' "$FILES" |
  grep -E '(^|/)((vitest|vite|jest|playwright|cypress|karma|webpack|rollup|rspack|rsbuild|esbuild|babel|postcss|tailwind|next|nuxt|svelte|astro|remix|angular|turbo|nx|lerna|biome|eslint|prettier|stylelint|knip|commitlint|tsup|storybook)\.[^/]*config[^/]*|[^/]*\.config\.[cm]?[jt]s|\.eslintrc[^/]*|eslint\.config\.[^/]+|\.prettierrc[^/]*|\.babelrc[^/]*|\.browserslistrc|tsconfig[^/]*\.json|jsconfig\.json|biome\.jsonc?|angular\.json|nx\.json|turbo\.json|\.storybook/[^/]+|\.editorconfig)$' || echo '(none)'

section "Large source files (> $MAX_LINES lines)"
source_files | tr '\n' '\0' | xargs -0 wc -l 2>/dev/null | grep -v ' total$' |
  awk -v max="$MAX_LINES" '$1 > max' | sort -rn | head -50 || true

section "Flat directories (>= $MAX_DIR_FILES files directly inside)"
files | awk '{ i = match($0, /\/[^\/]*$/); print (i ? substr($0, 1, i - 1) : ".") }' |
  sort | uniq -c | awk -v max="$MAX_DIR_FILES" '$1 >= max' | sort -rn | head -40

section 'Change hotspots (most edited files in the last 500 commits)'
git -c core.quotepath=off log -n 500 --format= --name-only -- "$SCOPE" 2>/dev/null |
  grep -Ev "$EXCLUDE_RE" | grep -E "$SOURCE_RE" | sort | uniq -c | sort -rn | head -20 || true

section 'Exact duplicate files (same content, different paths)'
# The empty blob is skipped; duplicated assets and generated evidence count too.
DUPES=$(git -c core.quotepath=off ls-files -s -- "$SCOPE" | awk -F'\t' '{ split($1, a, " "); print a[2] "\t" $2 }' |
  grep -Ev "$EXCLUDE_RE" | grep -v '^e69de29bb2d1d6434b8b29ae775ad8c2e48c5391' |
  awk -F'\t' '{ n[$1]++; p[$1] = p[$1] " " $2 } END { for (h in n) if (n[h] > 1) printf "%3d copies:%s\n", n[h], p[h] }' |
  sort -rn || true)
echo "duplicate groups: $(printf '%s' "$DUPES" | grep -c . || true)"
printf '%s\n' "$DUPES" | head -40

section 'Same function or exported symbol defined in several files (possible reimplementation)'
app_files | tr '\n' '\0' |
  xargs -0 grep -HoE '^(export[[:space:]]+(default[[:space:]]+)?(async[[:space:]]+)?(function\*?|const|let|class)|(async[[:space:]]+)?function\*?)[[:space:]]+[A-Za-z_$][A-Za-z0-9_$]*' 2>/dev/null |
  awk -F: '{
    file = $1; decl = $0; sub(/^[^:]*:/, "", decl)
    n = split(decl, w, /[[:space:]*]+/); name = w[n]
    if (name ~ /^(default|metadata|viewport|config|dynamic|revalidate|runtime|generateMetadata|generateStaticParams|generateViewport|loader|action|handler|middleware|proxy|GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|Page|Layout|Template|Loading|Error|NotFound|GlobalError|App|Root|meta|links|headers|prerender|load|main|setup)$/) next
    key = name SUBSEP file
    if (!(key in seen)) { seen[key] = 1; count[name]++; where[name] = where[name] " " file }
  } END { for (s in count) if (count[s] > 1) printf "%3d  %s:%s\n", count[s], s, where[s] }' |
  sort -rn | head -60 || true

section 'Deep relative imports (3+ levels up)'
app_files | count_list "from ['\"](\.\./){3,}|import\(['\"](\.\./){3,}|require\(['\"](\.\./){3,}" 20

section 'Suspicious and leftover files'
grep -Ei '(\.(bak|orig|rej|tmp|old|swp|log)$|(^|/)\.DS_Store$|(^|/)Thumbs\.db$|[ ._-](copy|old|backup|bak|v[0-9]+|new|final|temp|unused|deprecated)(\.[^/]*)?$| copy( [0-9]+)?\.[^/]*$|(^|/)(tmp|temp|old|backup|bak|scratch|unused|deprecated)/)' "$FILES" | head -60 || echo '(none)'

section 'Agent-style notes and reports in the repository'
grep -E '\.mdx?$' "$FILES" |
  grep -Ei '(^|/)[^/]*(summary|plan|notes|report|progress|todo|changes|implementation|analysis|fixes|refactor|status|review|handoff|session|walkthrough)[^/]*\.mdx?$' | head -40 || echo '(none)'

section 'Documentation files by length'
grep -E '\.mdx?$' "$FILES" | grep -Ev '(^|/)(node_modules|CHANGELOG)' | tr '\n' '\0' |
  xargs -0 wc -l 2>/dev/null | grep -v ' total$' | sort -rn | head -40 || true

section 'Test smells: focused, skipped and placeholder tests'
test_files | grep_list '\b(it|test|describe|context)\.(only|skip|todo|fixme)\b|\b(xit|xdescribe|xtest|fit|fdescribe)\(|test\.fail\(' 60

section 'Test smells: fixed waits and timers'
test_files | grep_list 'waitForTimeout\(|cy\.wait\([0-9]|setTimeout\(|sleep\(|new Promise\(\(?r(esolve)?\)? => setTimeout' 60

section 'Test smells: retries configured'
matching '(vitest|jest|playwright|cypress)[^/]*\.(json|[cm]?[jt]s)$|\.github/workflows/' | grep_list 'retries|retry' 30

section 'Test files without obvious assertions'
test_files | tr '\n' '\0' | xargs -0 grep -LE 'expect|assert|should|toMatch|toBe|toHave|cy\.|snapshot' 2>/dev/null | head -30 || true

section 'Type and lint suppressions (per file)'
source_files | count_list '@ts-ignore|@ts-nocheck|@ts-expect-error|eslint-disable|biome-ignore|\bas any\b|:[[:space:]]*any\b|<any>|# ?noqa|# type: ?ignore' 30

section 'Debug leftovers in application code (per file)'
app_files | count_list 'console\.(log|debug|trace)\(|^[[:space:]]*debugger;?' 30

section 'TODO / FIXME / HACK markers (per file)'
source_files | count_list '\b(TODO|FIXME|HACK|XXX)\b' 20

section 'Non-ASCII characters in code (possible non-English comments or identifiers)'
source_files | grep -Ev "$I18N_RE" | tr '\n' '\0' |
  LC_ALL=C xargs -0 grep -c '[^[:print:][:space:]]' 2>/dev/null |
  awk -F: '$NF > 0 { n = $NF; sub(/:[0-9]+$/, ""); printf "%5d  %s\n", n, $0 }' | sort -rn | head -30 || true

section 'Comment-heavy files (>= 25% comment lines and >= 15 comment lines)'
matching '\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|vue|svelte|astro|css|scss|less)$' | tr '\n' '\0' |
  xargs -0 awk '
    function flush() {
      if (file != "" && total > 0 && c >= 15 && c / total >= 0.25)
        printf "%4.0f%%  %4d of %-5d %s\n", 100 * c / total, c, total, file
    }
    FNR == 1 { flush(); file = FILENAME; c = 0; total = 0; block = 0 }
    {
      line = $0; sub(/^[ \t]+/, "", line)
      if (line == "") next
      total++
      if (block) { c++; if (line ~ /\*\//) block = 0; next }
      if (line ~ /^\/\//) { c++; next }
      if (line ~ /^\/\*/) { c++; if (line !~ /\*\//) block = 1; next }
      if (line ~ /^<!--/) { c++; next }
    }
    END { flush() }
  ' 2>/dev/null | sort -rn | head -30 || true

echo ''
echo '(end of scan)'
