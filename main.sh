#!/bin/bash
set -e
# Modified version of https://github.com/HDB-Li/LLIconVersioning

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

AC_ICONS_PATH="$AC_REPOSITORY_DIR/$AC_ICONS_PATH"
# Expand the glob once into an array so paths with spaces survive intact.
ICON_ROOTS=()
while IFS= read -r p; do ICON_ROOTS+=("$p"); done < <(compgen -G "$AC_ICONS_PATH")
if [ ${#ICON_ROOTS[@]} -gt 0 ]; then
    echo "Found icon directories matching: $AC_ICONS_PATH"
else
    echo "WARNING: No files or directories matched the icons glob."
    echo "WARNING:   Resolved glob: $AC_ICONS_PATH"
    echo "WARNING:   Searched under: ${AC_REPOSITORY_DIR:-$(pwd)}"
    echo "WARNING: Nothing to badge. Check the AC_ICONS_PATH input."
    exit 0
fi

if command -v magick &> /dev/null; then
    IM_CMD="magick"
else
    IM_CMD="convert"
fi

# Some ImageMagick builds have no default font; pass an explicit font file.
FONT_ARGS=()
resolve_font() {
    # If ImageMagick can already enumerate fonts, let it use its default.
    if $IM_CMD -list font 2>/dev/null | grep -q 'Font:'; then
        return
    fi

    local candidates=(
        "/System/Library/Fonts/Supplemental/Arial.ttf"
        "/Library/Fonts/Arial.ttf"
        "/System/Library/Fonts/Supplemental/Verdana.ttf"
        "/System/Library/Fonts/Helvetica.ttc"
        "/System/Library/Fonts/SFNSDisplay.ttf"
        "/System/Library/Fonts/SFNS.ttf"
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
    )

    local f
    for f in "${candidates[@]}"; do
        if [[ -f "$f" ]]; then
            FONT_ARGS=(-font "$f")
            echo "Using font: $f"
            return
        fi
    done

    echo "Warning: no usable font file found; relying on ImageMagick default font."
}

resolve_font

BADGE_TEXT="${AC_BADGE_TEXT:-Beta}"
BADGE_VERSION="${AC_BADGE_VERSION:-1.0}"
BADGE_BACKGROUND_COLOR="${AC_BADGE_BGCOLOR:-orange}"
BADGE_TEXT_COLOR="${AC_BADGE_TEXTCOLOR:-white}"
BADGE_CORNER_SHIFT=$(( ${AC_BADGE_CORNER_SHIFT:-5} ))
BADGE_FORCE_LEGACY="${AC_BADGE_FORCE_LEGACY:-true}"

BADGE_HEIGHT=20
BADGE_TEXT_MAX_WIDTH=60
BADGE_TEXT_MAX_HEIGHT=78

# Bottom app information parameters
ICON_INFO_FONT_SIZE=13
ICON_INFO_HEIGHT=30

echo "AC_BADGE_TEXT: $BADGE_TEXT"
echo "AC_BADGE_VERSION: $BADGE_VERSION"
echo "AC_BADGE_BGCOLOR: $BADGE_BACKGROUND_COLOR"
echo "AC_BADGE_TEXTCOLOR: $BADGE_TEXT_COLOR"
echo "AC_BADGE_CORNER_SHIFT: $BADGE_CORNER_SHIFT"
echo "AC_BADGE_FORCE_LEGACY: $BADGE_FORCE_LEGACY"

# Temp images
AC_TMP_BLURRED="ac_tmp_blurred.png"
AC_TMP_MASKED="ac_tmp_mask.png"
AC_TMP_LABELBASE="ac_tmp_labels-base.png"
AC_TMP_LABELS="ac_tmp_labels.png"
AC_TMP_TEMP="ac_tmp_temp.png"
AC_TMP_BADGE="ac_tmp_badge.png"
AC_TMP_BADGE_BG="ac_tmp_badge_bg.png"
AC_TMP_BADGE_TXT="ac_tmp_badge_txt.png"
AC_TMP_ALPHA="ac_tmp_alpha.png"

# processIcon <file> [clip_to_alpha]
# clip_to_alpha=true: clip badge to the icon silhouette (false for adaptive foregrounds)
# Body runs in a subshell so the cd below never leaks into the caller.
function processIcon() (
    base_file=$1
    clip_to_alpha=${2:-true}
    BASE_FLODER_PATH=$(dirname "$base_file")
    cd "$BASE_FLODER_PATH"
    base_file=$(basename "$base_file")
    width=$(identify -format %w "$base_file")
    height=$(identify -format %h "$base_file")
    badge_width_offset=$(( ($width * $BADGE_CORNER_SHIFT) / 100 ))
    badge_height_offset=$(( ($height * $BADGE_CORNER_SHIFT) / 100 ))
    band_height=$((($height * $ICON_INFO_HEIGHT) / 100))
    band_position=$(($height - $band_height))
    text_offset=$(awk "BEGIN {print int(1/5 * $band_position + 0.5)}")
    text_position=$(($band_position - $text_offset))
    point_size=$((($ICON_INFO_FONT_SIZE * $width) / 100))
    badge_width=$((($width * 200) / 100))
    badge_height=$((($height * $BADGE_HEIGHT) / 100))
    badge_text_width=$((($width * $BADGE_TEXT_MAX_WIDTH) / 100))
    badge_text_height=$((($badge_height * $BADGE_TEXT_MAX_HEIGHT) / 100))
    # avoid zero-sized boxes on tiny inputs
    if [ "$point_size" -lt 1 ]; then point_size=1; fi
    if [ "$badge_text_width" -lt 1 ]; then badge_text_width=1; fi
    if [ "$badge_text_height" -lt 1 ]; then badge_text_height=1; fi

    if [ "$clip_to_alpha" != "false" ]; then
        $IM_CMD "$base_file" -alpha extract $AC_TMP_ALPHA
    fi

    $IM_CMD "$base_file" -blur 10x8 $AC_TMP_BLURRED
    if [[ "$IM_CMD" == "magick" ]]; then
        $IM_CMD -size ${width}x${height} xc:black -fill white -draw "rectangle 0,$band_position $width,$height" $AC_TMP_MASKED
        $IM_CMD $AC_TMP_BLURRED $AC_TMP_MASKED -alpha off -compose CopyOpacity -composite $AC_TMP_MASKED
        $IM_CMD "${base_file}" $AC_TMP_MASKED -compose over -composite $AC_TMP_TEMP
    else
        $IM_CMD $AC_TMP_BLURRED -gamma 0 -fill white -draw "rectangle 0,$band_position,$width,$height" $AC_TMP_MASKED
    fi
    $IM_CMD -size ${width}x${band_height} xc:none -fill 'rgba(0,0,0,0.2)' -draw "rectangle 0,0,$width,$band_height" $AC_TMP_LABELBASE
    $IM_CMD -background none "${FONT_ARGS[@]}" -size ${width}x${band_height} -pointsize $point_size -fill $BADGE_TEXT_COLOR -gravity center -gravity South caption:"$BADGE_VERSION" $AC_TMP_LABELS
    $IM_CMD "$base_file" $AC_TMP_BLURRED $AC_TMP_MASKED -composite $AC_TMP_TEMP
    $IM_CMD $AC_TMP_TEMP $AC_TMP_LABELBASE -geometry +0+$band_position -composite $AC_TMP_LABELS -geometry +0+$text_position -composite "${base_file}"
    $IM_CMD -size ${badge_width}x${badge_height} xc:$BADGE_BACKGROUND_COLOR $AC_TMP_BADGE_BG
    $IM_CMD -background none "${FONT_ARGS[@]}" -fill $BADGE_TEXT_COLOR -size ${badge_text_width}x${badge_text_height} -gravity center label:"$BADGE_TEXT" $AC_TMP_BADGE_TXT
    $IM_CMD $AC_TMP_BADGE_BG $AC_TMP_BADGE_TXT -gravity center -composite $AC_TMP_BADGE
    $IM_CMD $AC_TMP_BADGE -background none -rotate 45 $AC_TMP_BADGE
    $IM_CMD "$base_file" $AC_TMP_BADGE -gravity SouthWest -geometry -${badge_width_offset}-${badge_height_offset} -composite "$base_file"

    if [ "$clip_to_alpha" != "false" ]; then
        $IM_CMD "$base_file" $AC_TMP_ALPHA -alpha off -compose CopyOpacity -composite "$base_file"
        rm $AC_TMP_ALPHA
    fi

    if [ $? != 0 ];then
        echo "The imagemagick command failed."
    fi

    rm $AC_TMP_BLURRED
    rm $AC_TMP_LABELBASE
    rm $AC_TMP_LABELS
    rm $AC_TMP_MASKED
    rm $AC_TMP_TEMP
    rm $AC_TMP_BADGE
    rm $AC_TMP_BADGE_BG
    rm $AC_TMP_BADGE_TXT
)

# Badge only the 66/108 safe zone of an adaptive foreground layer.
function processAdaptiveForeground() {
    local fg_file=$1
    local fg_width fg_height inset_x inset_y safe_width safe_height safe_tmp
    fg_width=$(identify -format %w "$fg_file")
    fg_height=$(identify -format %h "$fg_file")
    # (108-66)/2 = 21/108 inset per edge
    inset_x=$(( (fg_width * 21) / 108 ))
    inset_y=$(( (fg_height * 21) / 108 ))
    safe_width=$(( fg_width - 2 * inset_x ))
    safe_height=$(( fg_height - 2 * inset_y ))
    safe_tmp="$(dirname "$fg_file")/ac_tmp_safe_zone.png"

    $IM_CMD "$fg_file" -crop "${safe_width}x${safe_height}+${inset_x}+${inset_y}" +repage "$safe_tmp"
    processIcon "$safe_tmp" false
    $IM_CMD "$fg_file" "$safe_tmp" -geometry "+${inset_x}+${inset_y}" -composite "$fg_file"
    rm -f "$safe_tmp"
}

# Drawable refs of a layer (foreground/background) in an adaptive icon XML.
get_adaptive_layer_refs() {
    local xml_file=$1 layer=$2
    {
        tr '\n' ' ' < "$xml_file" | sed -n "s/.*<${layer}[^>]*android:drawable=\"@\([^\"]*\)\".*/\1/p"
        tr '\n' ' ' < "$xml_file" | sed -n "s/.*android:${layer}=\"@\([^\"]*\)\".*/\1/p"
    } | sort -u
}

# Resolve a drawable ref to raster files across density buckets.
resolve_layer_rasters() {
    local res_root=$1 rtype=${2%%/*} rname=${2#*/}
    find "$res_root" -type f \( -name "${rname}.png" -o -name "${rname}.webp" \) \
        \( -path "*/${rtype}/*" -o -path "*/${rtype}-*/*" \) ! -path "*-anydpi*" 2>/dev/null | sort -u
}

resolve_layer_vectors() {
    local res_root=$1 rtype=${2%%/*} rname=${2#*/}
    find "$res_root" -type f -name "${rname}.xml" \
        \( -path "*/${rtype}/*" -o -path "*/${rtype}-*/*" \) ! -path "*-anydpi*" 2>/dev/null | sort -u
}

list_contains() {
    printf '%s\n' "$1" | grep -Fqx -- "$2"
}

ICON_FILES=()
while IFS= read -r f; do ICON_FILES+=("$f"); done \
    < <(find "${ICON_ROOTS[@]}" -type f \( -name '*.png' -o -name '*.webp' \) 2>/dev/null | sort -u)
ADAPTIVE_XMLS=()
while IFS= read -r f; do ADAPTIVE_XMLS+=("$f"); done \
    < <(find "${ICON_ROOTS[@]}" -type f -path '*mipmap-anydpi*' -name 'ic_launcher*.xml' 2>/dev/null | sort -u)

if [ ${#ICON_FILES[@]} -eq 0 ] && [ ${#ADAPTIVE_XMLS[@]} -eq 0 ]; then
    echo "WARNING: No icon files (*.png / *.webp) or adaptive icon XMLs were found."
    echo "WARNING:   Resolved glob: $AC_ICONS_PATH"
    echo "WARNING:   Searched locations:"
    for p in "${ICON_ROOTS[@]}"; do echo "WARNING:     $p"; done
    echo "WARNING: Nothing to badge. Check the AC_ICONS_PATH input."
    exit 0
fi

PROCESSED_FILES=""   # adaptive foreground rasters already badged (safe-zone mode)
SKIP_FILES=""        # adaptive background rasters: never badge them
FALLBACK_ROOTS=""    # res roots whose foreground is vector-only
TOTAL_BADGED=0

for xml in "${ADAPTIVE_XMLS[@]}"; do
    echo "Found adaptive icon: $xml"
    res_root=$(dirname "$(dirname "$xml")")
    fg_refs=$(get_adaptive_layer_refs "$xml" foreground)
    bg_refs=$(get_adaptive_layer_refs "$xml" background)

    if [ -z "$fg_refs" ]; then
        echo "WARNING: No foreground drawable reference found in $xml; leaving it untouched."
        continue
    fi

    for ref in $fg_refs; do
        case "$ref" in */*) ;; *) continue ;; esac
        rasters=()
        while IFS= read -r f; do [ -n "$f" ] && rasters+=("$f"); done \
            < <(resolve_layer_rasters "$res_root" "$ref")
        if [ ${#rasters[@]} -gt 0 ]; then
            for f in "${rasters[@]}"; do
                if list_contains "$PROCESSED_FILES" "$f"; then
                    continue
                fi
                echo "Adding badge to adaptive icon foreground (safe zone) - $f"
                processAdaptiveForeground "$f"
                PROCESSED_FILES="$PROCESSED_FILES
$f"
                TOTAL_BADGED=$((TOTAL_BADGED + 1))
            done
        else
            vectors=$(resolve_layer_vectors "$res_root" "$ref")
            echo "===================================================================="
            echo "WARNING: The adaptive icon foreground '@$ref' referenced by"
            echo "WARNING:   $xml"
            if [ -n "$vectors" ]; then
                echo "WARNING: only exists as vector drawable XML:"
                printf '%s\n' "$vectors" | while read -r v; do echo "WARNING:   $v"; done
            else
                echo "WARNING: could not be resolved to any raster (.png/.webp) file."
            fi
            echo "WARNING: This step cannot draw a badge onto vector drawables, so the"
            echo "WARNING: badge would not be visible on the device launcher icon."
            echo "===================================================================="
            FALLBACK_ROOTS="$FALLBACK_ROOTS
$res_root"
        fi
    done

    # Never badge background layers.
    for ref in $bg_refs; do
        case "$ref" in */*) ;; *) continue ;; esac
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            if ! list_contains "$SKIP_FILES" "$f"; then
                SKIP_FILES="$SKIP_FILES
$f"
            fi
        done < <(resolve_layer_rasters "$res_root" "$ref")
    done
done

for f in "${ICON_FILES[@]}"; do
    if list_contains "$PROCESSED_FILES" "$f"; then
        continue
    fi
    if list_contains "$SKIP_FILES" "$f"; then
        echo "Skipping adaptive icon background layer - $f"
        continue
    fi
    echo "Adding badge to - $f"
    processIcon "$f"
    TOTAL_BADGED=$((TOTAL_BADGED + 1))
done

# Vector-only foregrounds: remove adaptive XMLs so badged legacy icons are used.
if [ -n "$(printf '%s' "$FALLBACK_ROOTS" | tr -d '[:space:]')" ]; then
    if [ "$BADGE_FORCE_LEGACY" != "false" ]; then
        echo "WARNING: Falling back to legacy icons: removing adaptive ic_launcher*.xml"
        echo "WARNING: files under mipmap directories so the badged legacy icons are used."
        echo "WARNING: Modern launchers may render these with white/boxed corners."
        echo "WARNING: Set AC_BADGE_FORCE_LEGACY=false to keep the adaptive icons instead."
        while IFS= read -r root; do
            [ -z "$root" ] && continue
            while IFS= read -r f; do
                [ -z "$f" ] && continue
                echo "Removing - $f"
                rm "$f"
            done < <(find "$root" -type f -path '*/mipmap*/*' -name 'ic_launcher*.xml' 2>/dev/null)
        done < <(printf '%s\n' "$FALLBACK_ROOTS" | sort -u)
    else
        echo "WARNING: AC_BADGE_FORCE_LEGACY=false - keeping adaptive icons untouched."
        echo "WARNING: The badge will NOT be visible on API 26+ device launchers for this icon."
    fi
fi

if [ "$TOTAL_BADGED" -eq 0 ]; then
    echo "WARNING: No icon file was badged."
    echo "WARNING:   Resolved glob: $AC_ICONS_PATH"
else
    echo "Done. Badged $TOTAL_BADGED icon file(s)."
fi
