/// Receives one diagnostic line from a store client.
///
/// Nothing is logged unless a caller supplies one of these. The package never
/// writes to stdout or stderr on its own — a library that prints is a library
/// you cannot embed.
///
/// What gets logged is deliberately narrow: requests, retries, and waits.
/// These are the things that make a run look hung, and the App Store's
/// asynchronous report endpoints can legitimately wait for tens of minutes.
///
/// ## Example
///
/// ```dart
/// final client = AppStoreConnectClient(
///   apiKey: key,
///   onLog: (message) => stderr.writeln('[asc] $message'),
/// );
/// ```
typedef StoreConsoleLog = void Function(String message);
