/// Which app store a piece of data came from.
///
/// Every model in this package carries one of these, so results merged from
/// both consoles stay attributable to their origin.
enum Store {
  /// Google Play, reached through the Google Play Developer API.
  googlePlay('Google Play'),

  /// The Apple App Store, reached through the App Store Connect API.
  appStore('App Store');

  const Store(this.displayName);

  /// Human-readable store name, for logs and UI.
  final String displayName;
}
