# Appcircle Badge

Add badge to your `.png` files.

Required Input Variables
- `$AC_ICONS_PATH`: Specifies path of icon files. For example : `$AC_REPOSITORY_DIR/MyProject/Assets.xcassets/AppIcon.appiconset`

Optional Input Variables
- `$AC_BADGE_TEXT`: Badge text. `Beta` by default
- `$AC_BADGE_VERSION`: Version or build number that will appear at the bottom. **TIP**: You can use "\n" in your string for a new line. `1.0` by default
- `$AC_BADGE_BGCOLOR`: Badge background color. You can use full color name (blue,orange,...), hex codes(#0000FF,#FFA500,...) or rgb values(rgb(0,0,255),rgb(255,165,0),...) `orange` by default
- `$AC_BADGE_TEXTCOLOR`: Badge version text color. You can use full color name (blue,orange,...), hex codes(#0000FF,#FFA500,...) or rgb values(rgb(0,0,255),rgb(255,165,0),...) `white` by default

Example
---
|Original|Modified|
|--------|------|
|![Original Image](assets/original.png?raw=true)|![Modified Image](assets/badged.png?raw=true")|