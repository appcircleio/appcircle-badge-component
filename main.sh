#!/bin/bash
set -e
# Modified version of https://github.com/HDB-Li/LLIconVersioning

if [ -z "$AC_ICONS_PATH" ]
then
    echo "AC_ICONS_PATH is not provided."
    exit 1
fi
AC_ICONS_PATH="$AC_REPOSITORY_DIR/$AC_ICONS_PATH"

if [ ! -d $AC_ICONS_PATH ]
then
    echo "Directory $AC_ICONS_PATH DOES NOT exists."
    exit 1
fi

if ! command -v convert &> /dev/null
then
    echo "Installing Imagemagick"
    OS=$(uname -s)
    if [ "${OS}" == "Linux" ]; then
        apt-get -y install imagemagick
        elif [ "${OS}" == "Darwin" ]; then
        brew install imagemagick
    fi
else
    echo "Imagemagick already installed"
fi

BADGE_TEXT="${AC_BADGE_TEXT:-Beta}"
BADGE_VERSION="${AC_BADGE_VERSION:-1.0}"
BADGE_BACKGROUND_COLOR="${AC_BADGE_BGCOLOR:-orange}"
BADGE_TEXT_COLOR="${AC_BADGE_TEXTCOLOR:-white}"

BADGE_FONT_SIZE=15
BADGE_HEIGHT=20

# Bottom app information parameters
ICON_INFO_FONT_SIZE=13
ICON_INFO_HEIGHT=30

echo "AC_BADGE_TEXT: $BADGE_TEXT"
echo "AC_BADGE_VERSION: $BADGE_VERSION"
echo "AC_BADGE_BGCOLOR: $BADGE_BACKGROUND_COLOR"
echo "AC_BADGE_TEXTCOLOR: $BADGE_TEXT_COLOR"

# Temp images
AC_TMP_BLURRED="ac_tmp_blurred.png"
AC_TMP_MASKED="ac_tmp_mask.png"
AC_TMP_LABELBASE="ac_tmp_labels-base.png"
AC_TMP_LABELS="ac_tmp_labels.png"
AC_TMP_TEMP="ac_tmp_temp.png"
AC_TMP_BADGE="ac_tmp_badge.png"

function processIcon() {
    base_file=$1
    BASE_FLODER_PATH=`dirname $base_file`
    cd "$BASE_FLODER_PATH"
    width=`identify -format %w ${base_file}`
    height=`identify -format %h ${base_file}`
    band_height=$((($height * $ICON_INFO_HEIGHT) / 100))
    band_position=$(($height - $band_height))
    text_position=$(($band_position - 3))
    point_size=$((($ICON_INFO_FONT_SIZE * $width) / 100))
    badge_width=$((($width * 200) / 100))
    badge_height=$((($height * $BADGE_HEIGHT) / 100))
    badge_point_size=$((($BADGE_FONT_SIZE * $width) / 100))
    target_file=`basename $base_file`
    convert ${base_file} -blur 10x8 $AC_TMP_BLURRED
    convert $AC_TMP_BLURRED -gamma 0 -fill white -draw "rectangle 0,$band_position,$width,$height" $AC_TMP_MASKED
    convert -size ${width}x${band_height} xc:none -fill 'rgba(0,0,0,0.2)' -draw "rectangle 0,0,$width,$band_height" $AC_TMP_LABELBASE
    convert -background none -size ${width}x${band_height} -pointsize $point_size -fill $BADGE_TEXT_COLOR -gravity center -gravity South caption:"$BADGE_VERSION" $AC_TMP_LABELS
    convert ${base_file} $AC_TMP_BLURRED $AC_TMP_MASKED -composite $AC_TMP_TEMP
    convert $AC_TMP_TEMP $AC_TMP_LABELBASE -geometry +0+$band_position -composite $AC_TMP_LABELS -geometry +0+$text_position -geometry +${w}-${h} -composite "${base_file}"
    convert -background $BADGE_BACKGROUND_COLOR -size ${badge_width}x${badge_height} -pointsize $badge_point_size -fill $BADGE_TEXT_COLOR -gravity center caption:$BADGE_TEXT $AC_TMP_BADGE
    convert $AC_TMP_BADGE -background none -rotate 45 $AC_TMP_BADGE
    convert ${base_file} $AC_TMP_BADGE -gravity SouthWest -composite ${base_file}
    
    if [ $? != 0 ];then
        echo "convert failed."
    fi
    
    rm $AC_TMP_BLURRED
    rm $AC_TMP_LABELBASE
    rm $AC_TMP_LABELS
    rm $AC_TMP_MASKED
    rm $AC_TMP_TEMP
    rm $AC_TMP_BADGE
}

for f in  `find  $AC_ICONS_PATH -name '*.png'`
do
    echo "Adding badge to - $f"
    processIcon "$f"
done

# Remove ic_launcher xml files to force badged icons
if [ "${OS}" == "Linux" ]; then
    echo "Removing adaptive icons to force badged icons"
    for f in  `find  $AC_ICONS_PATH -name 'ic_launcher*.xml'`
    do
        echo "Removing - $f"
        rm $f
    done
fi