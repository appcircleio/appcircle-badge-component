# Appcircle Badge

Add badge to your `.png` files.

Required Input Variables
- `$AC_ICONS_PATH`: Specifies path of icon files. 

For example:

- iOS Native: `MyProject/Assets.xcassets/AppIcon.appiconset`
- Android Native `app/src/main/res/`
- React Native iOS: `ios//MyProject/Assets.xcassets/AppIcon.appiconset/`
- React Native Android: `android/app/src/main/res/`
- Flutter iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset`
- Flutter Android: `android/app/src/main/res/`
- Smartface iOS: `images/iOS/AppIcon.appiconset`
- Smartface Android: `images/Android`


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