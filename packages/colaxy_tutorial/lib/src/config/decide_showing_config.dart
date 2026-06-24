/// A function type that determines whether to show a tutorial based
///  on build number and version.
typedef DecideShowingConfigCondition = bool Function({
  int buildNumber,
  String version,
});

/// Configuration class for deciding when to show tutorials.
sealed class DecideShowingConfig {
  /// Configuration that allows the user to choose to show just once.
  static DecideShowingConfigChooseByUserJustOnce get chooseByUserJustOnce =>
      DecideShowingConfigChooseByUserJustOnce();

  /// Configuration that shows the tutorial just once.
  static DecideShowingConfigJustOnce get justOnce =>
      DecideShowingConfigJustOnce();

  /// Configuration that shows the tutorial based on a custom condition.
  static DecideShowingConfigByCondition byCondition({
    required DecideShowingConfigCondition condition,
  }) =>
      DecideShowingConfigByCondition(condition: condition);
}

/// Configuration that shows tutorial based on a custom condition.
class DecideShowingConfigByCondition extends DecideShowingConfig {
  /// Creates a configuration with a custom condition.
  DecideShowingConfigByCondition({
    required this.condition,
  });

  /// The condition function that determines whether to show the tutorial.
  final DecideShowingConfigCondition condition;
}

/// Configuration that allows the user to choose to show the tutorial just once.
class DecideShowingConfigChooseByUserJustOnce extends DecideShowingConfig {}

/// Configuration that shows the tutorial just once.
class DecideShowingConfigJustOnce extends DecideShowingConfig {}
