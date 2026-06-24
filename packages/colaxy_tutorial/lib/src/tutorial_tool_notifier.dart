import 'package:colaxy_tutorial/colaxy_tutorial.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A dialog widget that notifies users about tutorials with optional
/// "don't show again" functionality.
class TutorialToolNotifier extends StatefulWidget {
  /// Creates a tutorial tool notifier dialog.
  const TutorialToolNotifier({
    required this.title,
    required this.child,
    required this.showDontShowAgain,
    super.key,
  });

  /// The title text for the dialog.
  final String title;

  /// The child widget to display in the dialog content.
  final Widget child;

  /// Whether to show the "don't show again" checkbox.
  final bool showDontShowAgain;

  @override
  State<TutorialToolNotifier> createState() => _TutorialToolNotifierState();
}

class _TutorialToolNotifierState extends State<TutorialToolNotifier> {
  bool dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: widget.child,
      actions: [
        if (widget.showDontShowAgain)
          GestureDetector(
            onTap: () => setState(() {
              dontShowAgain = !dontShowAgain;
            }),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: dontShowAgain,
                    onChanged: (value) {
                      setState(() {
                        dontShowAgain = value ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 7),
                Text('$packageName:dont_show_again'.tr()),
              ],
            ),
          ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(dontShowAgain),
          child: Text(
            '$packageName:understood'.tr(),
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ],
    );
  }
}
