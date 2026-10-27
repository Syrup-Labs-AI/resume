#!/usr/bin/env bash
# check-rules.sh -- enforce this repository's own CLAUDE.md, mechanically.
#
# WHY THIS EXISTS
#
# On 2026-10-27 an agent pushed to main six times, changed the job titles in
# index.html, and left resume.json and resume.txt saying something else:
#
#     "AI Program Manager"                       html=0  json=3  txt=4
#     "Director, Business Operations and AI..."  html=5  json=0  txt=0
#
# Alan's resume lied in two formats for about an hour. CLAUDE.md rule 2
# already forbids exactly this, and the commit history already names it twice
# ("truth pass part 2: resume.txt was missed", "truth pass part 3: resume.json,
# the last file carrying the claims"). The rule existed. Nothing enforced it.
#
# A rule a human has to remember is a rule that gets broken on the day they are
# tired. This is the same rule as a command.
#
# USAGE
#   bash check-rules.sh              check the working tree
#   bash check-rules.sh --selftest   prove the refusals refuse
#   ln -s ../../check-rules.sh .git/hooks/pre-commit    (wire it once)
#
# EXIT  0 clean   1 a rule was broken   2 could not run
set -uo pipefail
cd "$(dirname "$0")" || exit 2

FAILED=0
say()  { printf "  %-6s %s\n" "$1" "$2"; }
fail() { say "BROKE" "$1"; FAILED=1; }
ok()   { say "ok" "$1"; }

# ---------------------------------------------------------------- RULE 2
# "Three files carry the same claims; a change lands in all three or in none."
# Every title string must appear, or not appear, consistently. A string in the
# site but absent from both data files is a resume that lies in one format.
rule2() {
  local bad=0 s h j t
  # Titles are the claims that have actually drifted. Add a line to widen it.
  for s in "AI Program Manager" \
           "Director, Business Operations and AI Enablement" \
           "GoHighLevel"; do
    # NO `|| echo 0` here. grep -c PRINTS 0 and ALSO exits 1 on no match, so the
    # fallback appended a second line and every comparison silently broke. The
    # first version of this check shipped with that bug and its own selftest
    # caught it, which is the only reason the bug is not live.
    h=$(grep -c -- "$s" index.html 2>/dev/null); h=${h:-0}
    j=$(grep -c -- "$s" resume.json 2>/dev/null); j=${j:-0}
    t=$(grep -c -- "$s" resume.txt 2>/dev/null); t=${t:-0}
    # The counts need not be EQUAL (prose repeats differ). They must agree on
    # presence: if the site carries it, the data files must, and the reverse.
    if   [ "$h" -gt 0 ] && { [ "$j" -eq 0 ] || [ "$t" -eq 0 ]; }; then
      fail "rule 2: '$s' is in index.html but missing from a data file (html=$h json=$j txt=$t)"; bad=1
    elif [ "$h" -eq 0 ] && { [ "$j" -gt 0 ] || [ "$t" -gt 0 ]; }; then
      fail "rule 2: '$s' was removed from index.html but survives (html=$h json=$j txt=$t)"; bad=1
    fi
  done
  [ "$bad" -eq 0 ] && ok "rule 2: the three files agree on every tracked claim"
}

# ---------------------------------------------------------------- RULE 4
# The phone and email were wrong once (commit b53452f, the retired 443 number).
# Never typed from memory. The three files must agree on the tel: href.
rule4() {
  local n
  n=$(grep -o 'tel:[^"]*' index.html 2>/dev/null | sort -u | wc -l)
  if [ "$n" -gt 1 ]; then
    fail "rule 4: index.html carries $n different tel: hrefs"
  else
    ok "rule 4: one phone number in index.html"
  fi
}

# ---------------------------------------------------------------- RULE 5
# Estate rule 0: no em dashes, no double hyphens in prose. The ten em dashes
# already in index.html are Alan's to rule on and are RECORDED, not refused,
# so nobody adds an eleventh by accident.
rule5() {
  local em base=10
  em=$(grep -o '—' index.html 2>/dev/null | wc -l)
  if [ "$em" -gt "$base" ]; then
    fail "rule 5: index.html has $em em dashes, $base are Alan's known ones, $((em-base)) are new"
  else
    ok "rule 5: no new em dashes (found $em, baseline $base)"
  fi
  if grep -q -- ' -- ' resume.txt 2>/dev/null; then
    fail "rule 5: resume.txt contains a double hyphen in prose"
  else
    ok "rule 5: no double hyphen in resume.txt"
  fi
}

# ---------------------------------------------------------------- RULE 1
# render.js would destroy index.html. It must never run. If index.html ever
# loses its JSON-LD, that is the fingerprint of it having run.
rule1() {
  if grep -q 'application/ld+json' index.html 2>/dev/null; then
    ok "rule 1: JSON-LD still present, render.js has not run"
  else
    fail "rule 1: JSON-LD is GONE from index.html. render.js may have run."
  fi
}

# ---------------------------------------------------------------- selftest
# A check that has never refused anything is indistinguishable from a broken
# one, so each control is tripped on purpose in a scratch copy.
selftest() {
  local tmp pass=0 total=0
  tmp=$(mktemp -d) || exit 2
  cp index.html resume.json resume.txt check-rules.sh "$tmp/" 2>/dev/null
  t() { total=$((total+1)); if [ "$2" = "1" ]; then printf "  ok   %s\n" "$1"; pass=$((pass+1));
        else printf "  FAIL %s\n" "$1"; fi; }

  ( cd "$tmp" && bash check-rules.sh >/dev/null 2>&1 ); [ $? -eq 0 ] && r=1 || r=0
  t "a clean tree passes (positive control)" "$r"

  # RULE 2: remove the title from one data file only.
  ( cd "$tmp" && sed -i 's/Director, Business Operations and AI Enablement//g' resume.txt
    bash check-rules.sh >/dev/null 2>&1 ); [ $? -eq 1 ] && r=1 || r=0
  t "rule 2 refuses when resume.txt drifts from index.html" "$r"
  cp resume.txt "$tmp/resume.txt"

  # RULE 1: strip the JSON-LD, the fingerprint of render.js having run.
  ( cd "$tmp" && sed -i 's#application/ld+json#application/nope#' index.html
    bash check-rules.sh >/dev/null 2>&1 ); [ $? -eq 1 ] && r=1 || r=0
  t "rule 1 refuses when the JSON-LD disappears" "$r"
  cp index.html "$tmp/index.html"

  # RULE 5: add an em dash past the recorded baseline.
  ( cd "$tmp" && printf '\n<!-- %s -->\n' "$(printf '———')" >> index.html
    bash check-rules.sh >/dev/null 2>&1 ); [ $? -eq 1 ] && r=1 || r=0
  t "rule 5 refuses a new em dash" "$r"

  rm -rf "$tmp"
  echo
  echo "check-rules selftest: $pass/$total"
  [ "$pass" -eq "$total" ] && return 0 || return 1
}

if [ "${1:-}" = "--selftest" ]; then selftest; exit $?; fi
if [ -n "${1:-}" ]; then echo "check-rules: unknown option $1" >&2; exit 2; fi

echo "check-rules, enforcing this repo's CLAUDE.md:"
rule1; rule2; rule4; rule5
echo
if [ "$FAILED" -eq 1 ]; then
  echo "REFUSED. A rule in CLAUDE.md was broken. Fix the files, not the check."
  exit 1
fi
echo "all checked rules hold"
exit 0
