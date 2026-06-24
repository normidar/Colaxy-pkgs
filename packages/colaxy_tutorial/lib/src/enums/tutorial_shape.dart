import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Defines the shape of the tutorial focus area.
sealed class TutorialShape {
  /// Creates a tutorial shape with the specified focus shape.
  const TutorialShape(this.shape);

  /// A circular tutorial focus shape.
  static TutorialShape get circle => const _TutorialShapeCircle();

  /// A rounded rectangle tutorial focus shape.
  static TutorialShape get rRect => const _TutorialShapeRRect();

  /// The underlying shape light focus configuration.
  final ShapeLightFocus shape;
}

/// Internal implementation of circular tutorial shape.
class _TutorialShapeCircle extends TutorialShape {
  /// Creates a circular tutorial shape.
  const _TutorialShapeCircle() : super(ShapeLightFocus.Circle);
}

/// Internal implementation of rounded rectangle tutorial shape.
class _TutorialShapeRRect extends TutorialShape {
  /// Creates a rounded rectangle tutorial shape.
  const _TutorialShapeRRect() : super(ShapeLightFocus.RRect);
}
