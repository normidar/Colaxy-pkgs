import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Defines the alignment of tutorial content relative to the focus area.
sealed class TutorialAlign {
  /// Creates a tutorial alignment with the specified content alignment.
  const TutorialAlign._({required ContentAlign contentAlign})
      : _contentAlign = contentAlign;

  /// Aligns tutorial content to the bottom of the focus area.
  static TutorialAlign get bottom => const _TutorialAlignBottom();

  /// Aligns tutorial content to the left of the focus area.
  static TutorialAlign get left => const _TutorialAlignLeft();

  /// Aligns tutorial content to the right of the focus area.
  static TutorialAlign get right => const _TutorialAlignRight();

  /// Aligns tutorial content to the top of the focus area.
  static TutorialAlign get top => const _TutorialAlignTop();

  final ContentAlign _contentAlign;

  /// このパッケージしか使わない
  ContentAlign get contentAlign => _contentAlign;
}

/// Internal implementation of bottom-aligned tutorial content.
class _TutorialAlignBottom extends TutorialAlign {
  /// Creates a bottom-aligned tutorial alignment.
  const _TutorialAlignBottom() : super._(contentAlign: ContentAlign.bottom);
}

/// Internal implementation of left-aligned tutorial content.
class _TutorialAlignLeft extends TutorialAlign {
  /// Creates a left-aligned tutorial alignment.
  const _TutorialAlignLeft() : super._(contentAlign: ContentAlign.left);
}

/// Internal implementation of right-aligned tutorial content.
class _TutorialAlignRight extends TutorialAlign {
  /// Creates a right-aligned tutorial alignment.
  const _TutorialAlignRight() : super._(contentAlign: ContentAlign.right);
}

/// Internal implementation of top-aligned tutorial content.
class _TutorialAlignTop extends TutorialAlign {
  /// Creates a top-aligned tutorial alignment.
  const _TutorialAlignTop() : super._(contentAlign: ContentAlign.top);
}
