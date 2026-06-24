import 'package:colaxy_tutorial/colaxy_tutorial.dart';
import 'package:flutter/material.dart';

/// A data set containing all the information needed to display a tutorial step.
class TutorialDataSet {
  /// Creates a tutorial data set with the specified properties.
  TutorialDataSet({
    required this.id,
    required this.key,
    required this.align,
    required this.shape,
    required this.builder,
  });

  /// Unique identifier for this tutorial step.
  final String id;

  /// The global key that identifies the widget to highlight.
  final GlobalKey key;

  /// The alignment of the tutorial content relative to the focus area.
  final TutorialAlign align;

  /// The shape of the focus area around the target widget.
  final TutorialShape shape;

  /// Builder function that creates the tutorial content widget.
  final Widget Function(BuildContext context) builder;
}
