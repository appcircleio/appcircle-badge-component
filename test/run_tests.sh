#!/bin/bash
# Test suite for main.sh. Runs entirely locally:
#   bash test/run_tests.sh
# Fixture res/ trees are generated on the fly with ImageMagick, so no binary
# fixtures are committed. Previews for manual visual inspection are written to
# test/output/.
set -u

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$TEST_DIR")"
MAIN_SH="$REPO_ROOT/main.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/badge-tests.XXXXXX")"
OUT_DIR="$TEST_DIR/output"
mkdir -p "$OUT_DIR"

if command -v magick &> /dev/null; then
    IM="magick"
elif command -v convert &> /dev/null; then
    IM="convert"
else
    echo "ERROR: ImageMagick (magick/convert) is required to run the tests." >&2
    exit 1
fi

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
section() { echo; echo "== $1 =="; }

sum() { cksum "$1" | awk '{print $1, $2}'; }

# Checksum every file under a directory tree (for "nothing here changed").
tree_sums() {
    ( cd "$1" && find . -type f | sort | while read -r f; do
        printf '%s  %s\n' "$(cksum "$f" | awk '{print $1, $2}')" "$f"
    done )
}

assert_changed() { # desc file old_sum
    if [ "$(sum "$2")" != "$3" ]; then pass "$1"; else fail "$1 (file unchanged: $2)"; fi
}
assert_unchanged() { # desc file old_sum
    if [ "$(sum "$2")" = "$3" ]; then pass "$1"; else fail "$1 (file changed: $2)"; fi
}
assert_contains() { # desc haystack needle
    if printf '%s' "$2" | grep -qi -- "$3"; then pass "$1"; else fail "$1 (output missing: $3)"; fi
}
assert_not_contains() { # desc haystack needle
    if printf '%s' "$2" | grep -qi -- "$3"; then fail "$1 (output contains: $3)"; else pass "$1"; fi
}

# Run main.sh against a fixture repo. Extra env assignments may be passed as
# NAME=value arguments. Sets OUTPUT and STATUS.
run_main() {
    local repo=$1 glob=$2
    shift 2
    OUTPUT=$(cd "$repo" && env AC_REPOSITORY_DIR="$repo" AC_ICONS_PATH="$glob" "$@" bash "$MAIN_SH" 2>&1)
    STATUS=$?
}

make_raster() { # path size
    mkdir -p "$(dirname "$1")"
    "$IM" -size "$2x$2" gradient:'#3355ff-#22cc88' -swirl 90 "$1"
}

write_adaptive_xml() { # path fg_ref bg_ref
    mkdir -p "$(dirname "$1")"
    cat > "$1" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@$3"/>
    <foreground android:drawable="@$2"/>
</adaptive-icon>
EOF
}

write_vector_xml() { # path
    mkdir -p "$(dirname "$1")"
    cat > "$1" <<EOF
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#3355FF" android:pathData="M0,0h108v108h-108z"/>
</vector>
EOF
}

GLOB='app/src/main/res/mipmap*'

# ---------------------------------------------------------------------------
section "Case A: legacy png-only res tree"
A="$WORK/case_a"
RES="$A/app/src/main/res"
make_raster "$RES/mipmap-mdpi/ic_launcher.png" 48
make_raster "$RES/mipmap-hdpi/ic_launcher.png" 72
make_raster "$RES/mipmap-hdpi/ic_launcher_round.png" 72
a1=$(sum "$RES/mipmap-mdpi/ic_launcher.png")
a2=$(sum "$RES/mipmap-hdpi/ic_launcher.png")
a3=$(sum "$RES/mipmap-hdpi/ic_launcher_round.png")

run_main "$A" "$GLOB"
[ "$STATUS" -eq 0 ] && pass "exit code 0" || fail "exit code was $STATUS"
assert_changed "mdpi ic_launcher.png badged" "$RES/mipmap-mdpi/ic_launcher.png" "$a1"
assert_changed "hdpi ic_launcher.png badged" "$RES/mipmap-hdpi/ic_launcher.png" "$a2"
assert_changed "hdpi ic_launcher_round.png badged" "$RES/mipmap-hdpi/ic_launcher_round.png" "$a3"
[ -z "$(find "$A" -name 'ac_tmp_*' -print -quit)" ] && pass "no temp files left behind" || fail "temp files left behind"

# ---------------------------------------------------------------------------
section "Case A2: transparent-margin icon keeps its silhouette (iOS-like clip)"
A2="$WORK/case_a2"
RES="$A2/app/src/main/res"
mkdir -p "$RES/mipmap-hdpi"
# Rounded-rect icon with transparent corners, like real launcher icons.
"$IM" -size 96x96 xc:none -fill '#eb1c24' -draw "roundrectangle 0,0 95,95 20,20" \
    "$RES/mipmap-hdpi/ic_launcher.png"
a2_sum=$(sum "$RES/mipmap-hdpi/ic_launcher.png")

run_main "$A2" "$GLOB"
[ "$STATUS" -eq 0 ] && pass "exit code 0" || fail "exit code was $STATUS"
f="$RES/mipmap-hdpi/ic_launcher.png"
assert_changed "transparent-margin icon badged" "$f" "$a2_sum"
corner_bl=$("$IM" "$f" -format '%[fx:u.p{1,94}.a]' info:)
corner_tr=$("$IM" "$f" -format '%[fx:u.p{94,1}.a]' info:)
band_mid=$("$IM" "$f" -format '%[fx:u.p{48,90}.a]' info:)
[ "$corner_bl" = "0" ] && pass "bottom-left corner stayed transparent (no black band spill)" \
    || fail "bottom-left corner became opaque (alpha=$corner_bl)"
[ "$corner_tr" = "0" ] && pass "top-right corner stayed transparent (ribbon clipped)" \
    || fail "top-right corner became opaque (alpha=$corner_tr)"
[ "$band_mid" = "1" ] && pass "version band still opaque inside the icon" \
    || fail "band center not opaque (alpha=$band_mid)"

# ---------------------------------------------------------------------------
section "Case B: adaptive icon with raster png foreground"
B="$WORK/case_b"
RES="$B/app/src/main/res"
write_adaptive_xml "$RES/mipmap-anydpi-v26/ic_launcher.xml" "mipmap/ic_launcher_foreground" "mipmap/ic_launcher_background"
write_adaptive_xml "$RES/mipmap-anydpi-v26/ic_launcher_round.xml" "mipmap/ic_launcher_foreground" "mipmap/ic_launcher_background"
make_raster "$RES/mipmap-mdpi/ic_launcher.png" 48
make_raster "$RES/mipmap-mdpi/ic_launcher_foreground.png" 108
make_raster "$RES/mipmap-mdpi/ic_launcher_background.png" 108
make_raster "$RES/mipmap-hdpi/ic_launcher.png" 72
make_raster "$RES/mipmap-hdpi/ic_launcher_foreground.png" 162
make_raster "$RES/mipmap-hdpi/ic_launcher_background.png" 162
make_raster "$RES/drawable-hdpi/other_asset.png" 64
b_xml1=$(sum "$RES/mipmap-anydpi-v26/ic_launcher.xml")
b_xml2=$(sum "$RES/mipmap-anydpi-v26/ic_launcher_round.xml")
b_fg1=$(sum "$RES/mipmap-mdpi/ic_launcher_foreground.png")
b_fg2=$(sum "$RES/mipmap-hdpi/ic_launcher_foreground.png")
b_bg1=$(sum "$RES/mipmap-mdpi/ic_launcher_background.png")
b_bg2=$(sum "$RES/mipmap-hdpi/ic_launcher_background.png")
b_l1=$(sum "$RES/mipmap-mdpi/ic_launcher.png")
b_l2=$(sum "$RES/mipmap-hdpi/ic_launcher.png")
b_drawable_before=$(tree_sums "$RES/drawable-hdpi")
cp "$RES/mipmap-hdpi/ic_launcher_foreground.png" "$WORK/b_fg_before.png"

run_main "$B" "$GLOB"
[ "$STATUS" -eq 0 ] && pass "exit code 0" || fail "exit code was $STATUS"
assert_changed "mdpi foreground badged" "$RES/mipmap-mdpi/ic_launcher_foreground.png" "$b_fg1"
assert_changed "hdpi foreground badged" "$RES/mipmap-hdpi/ic_launcher_foreground.png" "$b_fg2"
assert_changed "mdpi legacy ic_launcher badged" "$RES/mipmap-mdpi/ic_launcher.png" "$b_l1"
assert_changed "hdpi legacy ic_launcher badged" "$RES/mipmap-hdpi/ic_launcher.png" "$b_l2"
assert_unchanged "ic_launcher.xml untouched" "$RES/mipmap-anydpi-v26/ic_launcher.xml" "$b_xml1"
assert_unchanged "ic_launcher_round.xml untouched" "$RES/mipmap-anydpi-v26/ic_launcher_round.xml" "$b_xml2"
assert_unchanged "mdpi background layer not badged" "$RES/mipmap-mdpi/ic_launcher_background.png" "$b_bg1"
assert_unchanged "hdpi background layer not badged" "$RES/mipmap-hdpi/ic_launcher_background.png" "$b_bg2"
[ "$(tree_sums "$RES/drawable-hdpi")" = "$b_drawable_before" ] && pass "drawable-hdpi/ untouched" || fail "drawable-hdpi/ was modified"
assert_not_contains "no legacy fallback triggered" "$OUTPUT" "falling back"
assert_contains "foreground badged in safe-zone mode" "$OUTPUT" "safe zone"

# Safe-zone containment: on the 162px foreground, all pixel changes must lie
# inside the central 66/108 box ((108-66)/2/108 -> inset 21*162/108 = 31px).
fg="$RES/mipmap-hdpi/ic_launcher_foreground.png"
inset=$(( (162 * 21) / 108 ))
far=$(( 162 - inset ))
# Two steps: measuring inline via info: includes ImageMagick's internal meta
# channel and misreports the max, so write the masked diff first, then measure.
"$IM" "$WORK/b_fg_before.png" "$fg" -compose difference -composite -colorspace gray \
    -alpha off -fill black -draw "rectangle $inset,$inset $far,$far" "$WORK/b_outside_diff.png"
outside_max=$("$IM" "$WORK/b_outside_diff.png" -format '%[fx:maxima]' info:)
if [ "$outside_max" = "0" ]; then
    pass "no pixel changed outside the 66/108 safe zone"
else
    fail "pixels changed outside safe zone (max diff: $outside_max)"
fi

# Previews for manual visual inspection: badged foreground over a plain
# background, masked with the guaranteed-visible safe-zone circle (66/108)
# and a typical launcher circle mask (~72/108).
for mask in 66 72; do
    d=$(( (162 * mask) / 108 )); r=$(( d / 2 )); top=$(( 81 - r ))
    "$IM" -size 162x162 xc:'#e8e8e8' "$fg" -composite \
        \( -size 162x162 xc:black -fill white -draw "circle 81,81 81,$top" \) \
        -alpha off -compose CopyOpacity -composite "$OUT_DIR/preview_mask_${mask}of108.png"
done
echo "  (previews written to $OUT_DIR for visual check)"

# ---------------------------------------------------------------------------
section "Case C: adaptive icon with webp icons"
C="$WORK/case_c"
RES="$C/app/src/main/res"
write_adaptive_xml "$RES/mipmap-anydpi-v26/ic_launcher.xml" "mipmap/ic_launcher_foreground" "drawable/ic_launcher_background"
make_raster "$RES/mipmap-mdpi/ic_launcher.webp" 48
make_raster "$RES/mipmap-mdpi/ic_launcher_foreground.webp" 108
make_raster "$RES/mipmap-hdpi/ic_launcher.webp" 72
make_raster "$RES/mipmap-hdpi/ic_launcher_foreground.webp" 162
write_vector_xml "$RES/drawable/ic_launcher_background.xml"
c_xml=$(sum "$RES/mipmap-anydpi-v26/ic_launcher.xml")
c_fg=$(sum "$RES/mipmap-hdpi/ic_launcher_foreground.webp")
c_l1=$(sum "$RES/mipmap-mdpi/ic_launcher.webp")
c_l2=$(sum "$RES/mipmap-hdpi/ic_launcher.webp")
c_drawable_before=$(tree_sums "$RES/drawable")

run_main "$C" "$GLOB"
[ "$STATUS" -eq 0 ] && pass "exit code 0" || fail "exit code was $STATUS"
assert_changed "hdpi webp foreground badged" "$RES/mipmap-hdpi/ic_launcher_foreground.webp" "$c_fg"
assert_changed "mdpi webp legacy icon badged" "$RES/mipmap-mdpi/ic_launcher.webp" "$c_l1"
assert_changed "hdpi webp legacy icon badged" "$RES/mipmap-hdpi/ic_launcher.webp" "$c_l2"
assert_unchanged "ic_launcher.xml untouched" "$RES/mipmap-anydpi-v26/ic_launcher.xml" "$c_xml"
[ "$(tree_sums "$RES/drawable")" = "$c_drawable_before" ] && pass "drawable/ untouched" || fail "drawable/ was modified"
fmt=$("$IM" identify -format '%m' "$RES/mipmap-hdpi/ic_launcher_foreground.webp" 2>/dev/null || identify -format '%m' "$RES/mipmap-hdpi/ic_launcher_foreground.webp")
[ "$fmt" = "WEBP" ] && pass "webp output kept webp format" || fail "output format is $fmt, expected WEBP"
assert_not_contains "no legacy fallback triggered" "$OUTPUT" "falling back"

# ---------------------------------------------------------------------------
section "Case D: adaptive icon with vector-only foreground (fallback)"
build_case_d() { # root
    local RES="$1/app/src/main/res"
    write_adaptive_xml "$RES/mipmap-anydpi-v26/ic_launcher.xml" "drawable/ic_launcher_foreground" "drawable/ic_launcher_background"
    write_vector_xml "$RES/drawable/ic_launcher_foreground.xml"
    write_vector_xml "$RES/drawable/ic_launcher_background.xml"
    write_vector_xml "$RES/drawable-v24/ic_launcher_foreground.xml"
    make_raster "$RES/mipmap-mdpi/ic_launcher.png" 48
    make_raster "$RES/mipmap-hdpi/ic_launcher.png" 72
}

D="$WORK/case_d_default"
build_case_d "$D"
RES="$D/app/src/main/res"
d_l1=$(sum "$RES/mipmap-mdpi/ic_launcher.png")
d_drawable_before=$(tree_sums "$RES/drawable")

run_main "$D" "$GLOB"
[ "$STATUS" -eq 0 ] && pass "exit code 0" || fail "exit code was $STATUS"
assert_contains "vector-only warning printed" "$OUTPUT" "vector drawable"
assert_contains "legacy fallback announced" "$OUTPUT" "falling back"
[ ! -f "$RES/mipmap-anydpi-v26/ic_launcher.xml" ] && pass "adaptive XML removed (default AC_BADGE_FORCE_LEGACY=true)" || fail "adaptive XML still present"
[ -f "$RES/drawable/ic_launcher_foreground.xml" ] && pass "drawable/ vector foreground NOT deleted" || fail "drawable/ vector foreground was deleted"
[ -f "$RES/drawable-v24/ic_launcher_foreground.xml" ] && pass "drawable-v24/ vector NOT deleted" || fail "drawable-v24/ vector was deleted"
[ "$(tree_sums "$RES/drawable")" = "$d_drawable_before" ] && pass "drawable/ untouched" || fail "drawable/ was modified"
assert_changed "legacy png still badged" "$RES/mipmap-mdpi/ic_launcher.png" "$d_l1"

D2="$WORK/case_d_optout"
build_case_d "$D2"
RES="$D2/app/src/main/res"
run_main "$D2" "$GLOB" AC_BADGE_FORCE_LEGACY=false
[ "$STATUS" -eq 0 ] && pass "exit code 0 with AC_BADGE_FORCE_LEGACY=false" || fail "exit code was $STATUS"
assert_contains "vector-only warning printed" "$OUTPUT" "vector drawable"
[ -f "$RES/mipmap-anydpi-v26/ic_launcher.xml" ] && pass "adaptive XML kept (AC_BADGE_FORCE_LEGACY=false)" || fail "adaptive XML was removed despite opt-out"
assert_contains "opt-out consequence explained" "$OUTPUT" "NOT be visible"

# ---------------------------------------------------------------------------
section "Case E: zero-match warnings (exit 0, not silent)"
run_main "$WORK/case_a" 'app/src/main/res/bogus*'
[ "$STATUS" -eq 0 ] && pass "bogus glob exits 0" || fail "bogus glob exit code was $STATUS"
assert_contains "warning printed for bogus glob" "$OUTPUT" "WARNING"
assert_contains "resolved glob listed" "$OUTPUT" "bogus"

E="$WORK/case_e_empty"
mkdir -p "$E/app/src/main/res/mipmap-mdpi" "$E/app/src/main/res/mipmap-hdpi"
run_main "$E" "$GLOB"
[ "$STATUS" -eq 0 ] && pass "empty icon dirs exit 0" || fail "empty dirs exit code was $STATUS"
assert_contains "warning printed for empty icon dirs" "$OUTPUT" "No icon files"
assert_contains "searched locations listed" "$OUTPUT" "mipmap-mdpi"

# ---------------------------------------------------------------------------
section "Case F: platform independence"
if grep -Eq '\$\{?OS\}?' "$MAIN_SH"; then
    fail "main.sh still references \$OS"
else
    pass "no \$OS references remain in main.sh"
fi
if bash -n "$MAIN_SH"; then pass "main.sh passes bash -n syntax check"; else fail "bash -n failed"; fi

# ---------------------------------------------------------------------------
echo
echo "======================================"
echo "Results: $PASS passed, $FAIL failed"
echo "Fixtures: $WORK"
echo "Previews: $OUT_DIR"
echo "======================================"
[ "$FAIL" -eq 0 ]
