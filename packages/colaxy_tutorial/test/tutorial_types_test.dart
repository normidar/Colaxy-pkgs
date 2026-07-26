import 'package:colaxy_tutorial/colaxy_tutorial.dart';
import 'package:colaxy_tutorial/src/config/decide_showing_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

void main() {
  group('TutorialAlign', () {
    test('maps each alignment to the matching ContentAlign', () {
      expect(TutorialAlign.top.contentAlign, ContentAlign.top);
      expect(TutorialAlign.bottom.contentAlign, ContentAlign.bottom);
      expect(TutorialAlign.left.contentAlign, ContentAlign.left);
      expect(TutorialAlign.right.contentAlign, ContentAlign.right);
    });
  });

  group('TutorialShape', () {
    test('maps each shape to the matching ShapeLightFocus', () {
      expect(TutorialShape.circle.shape, ShapeLightFocus.Circle);
      expect(TutorialShape.rRect.shape, ShapeLightFocus.RRect);
    });
  });

  group('DecideShowingConfig', () {
    test('factories return the matching config types', () {
      expect(
        DecideShowingConfig.justOnce,
        isA<DecideShowingConfigJustOnce>(),
      );
      expect(
        DecideShowingConfig.chooseByUserJustOnce,
        isA<DecideShowingConfigChooseByUserJustOnce>(),
      );
      expect(
        DecideShowingConfig.byCondition(
          condition: ({buildNumber = 0, version = ''}) => true,
        ),
        isA<DecideShowingConfigByCondition>(),
      );
    });

    test('byCondition keeps the given condition', () {
      var called = false;
      final config = DecideShowingConfig.byCondition(
        condition: ({buildNumber = 0, version = ''}) {
          called = true;
          return buildNumber > 5;
        },
      );

      expect(config.condition(buildNumber: 10, version: '1.0.0'), isTrue);
      expect(called, isTrue);
      expect(config.condition(buildNumber: 1, version: '1.0.0'), isFalse);
    });
  });

  group('TutorialDataSet', () {
    test('holds the given values', () {
      final key = GlobalKey();
      final dataSet = TutorialDataSet(
        id: 'step1',
        key: key,
        align: TutorialAlign.bottom,
        shape: TutorialShape.circle,
        builder: (context) => const Text('content'),
      );

      expect(dataSet.id, 'step1');
      expect(dataSet.key, key);
      expect(dataSet.align.contentAlign, ContentAlign.bottom);
      expect(dataSet.shape.shape, ShapeLightFocus.Circle);
    });
  });
}
