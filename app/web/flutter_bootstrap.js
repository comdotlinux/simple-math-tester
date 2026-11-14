{{flutter_js}}
{{flutter_build_config}}
// Fallback fonts for glyphs the bundled Roboto lacks are requested from the
// app's own origin, where they do not exist, instead of from Google.
_flutter.loader.load({config: {fontFallbackBaseUrl: '/no-font-fallback/'}});
