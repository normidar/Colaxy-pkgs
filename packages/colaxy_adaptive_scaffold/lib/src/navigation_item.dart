import 'package:colaxy_adaptive_scaffold/src/adaptive_scaffold.dart'
    show AdaptiveScaffold;
import 'package:flutter/material.dart';

/// A navigation item that contains the name, icon, and page widget.
///
/// This class is used by [AdaptiveScaffold] to define each navigation
/// destination. Each item includes:
/// - [name]: The label text displayed in the navigation UI
/// - [icon]: The icon widget shown for this navigation item
/// - [page]: The page widget displayed when this item is selected
///
/// Example:
/// ```dart
/// NavigationItem(
///   name: 'ホーム',
///   icon: Icon(Icons.home),
///   page: HomePage(),
/// )
/// ```
class NavigationItem {
  /// Creates a navigation item.
  ///
  /// Required:
  /// - [name]: The label text for this navigation item
  /// - [icon]: The icon widget to display
  /// - [page]: The page widget to show when selected
  ///
  /// Optional:
  /// - [selectedIcon]: The icon to display while this item is selected
  /// - [tooltip]: Tooltip text for this destination
  const NavigationItem({
    required this.name,
    required this.icon,
    required this.page,
    this.selectedIcon,
    this.tooltip,
  });

  /// The name/label of the navigation item.
  ///
  /// This text is displayed in both the [NavigationBar] (bottom navigation)
  /// and [NavigationRail] (side navigation).
  final String name;

  /// The icon widget to display for this navigation item.
  ///
  /// Typically an [Icon] widget, but can be any widget.
  final Widget icon;

  /// The page widget to display when this navigation item is selected.
  ///
  /// This is the main content that will be shown in the scaffold body
  /// when the user selects this navigation item.
  final Widget page;

  /// The icon to display while this navigation item is selected.
  ///
  /// When null, [icon] is used for both the selected and unselected states.
  final Widget? selectedIcon;

  /// Optional tooltip text for this destination.
  final String? tooltip;
}
