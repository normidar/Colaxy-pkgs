import 'package:colaxy_adaptive_scaffold/src/navigation_item.dart';
import 'package:flutter/material.dart';

/// A scaffold that adapts between a [NavigationBar] and a [NavigationRail]
/// based on the screen aspect ratio (width/height).
///
/// This widget automatically determines the best navigation layout based on
/// the device's aspect ratio:
/// - **Portrait/Narrow screens** (aspect ratio < threshold): Uses
///   [NavigationBar] at the bottom
/// - **Landscape/Wide screens** (aspect ratio >= threshold): Uses
///   [NavigationRail] on the left side
///
/// The widget manages navigation state internally, so you don't need to track
/// the selected index yourself. Pass [onDestinationSelected] if you want to be
/// notified of changes.
///
/// Every page stays alive in an [IndexedStack], so switching destinations
/// preserves each page's state.
///
/// ## Parameters
///
/// ### Required Parameters
///
/// - **[items]**: A list of [NavigationItem] objects defining each navigation
///   destination. Each item contains a name (label), icon, and the page widget
///   to display.
///
/// ### Optional Parameters
///
/// - **[initialIndex]**: The initially selected navigation item index
///   (default: 0). Must be a valid index within the [items] list.
///
/// - **[aspectRatioThreshold]**: The aspect ratio threshold for switching
///   layouts (default: 1.2).
///   - If `width/height >= threshold`: Shows [NavigationRail] (side navigation)
///   - If `width/height < threshold`: Shows [NavigationBar] (bottom navigation)
///   - Common values:
///     - `1.0`: Switch at square screens
///     - `1.2`: Switch at slightly landscape screens (default)
///     - `1.5`: Switch only at wider landscape screens
///
/// - **[floatingActionButton]**: An optional [FloatingActionButton] to display.
///
/// - **[maxBottomNavigationItems]**: Maximum navigation items for bottom
///   navigation (default: 4). In portrait mode, if the number of items exceeds
///   this value, a [Drawer] menu will be used instead of [NavigationBar].
///
/// - **[drawerTitle]**: Heading shown in the drawer (default: no header).
///
/// - **[onDestinationSelected]**: Called when the selection changes.
///
/// - **[appBar]**: App bar shown in every layout, so the chrome does not
///   appear and disappear as the window is resized.
///
/// - **[railLeading]** / **[railTrailing]**: Widgets above and below the
///   destinations in the rail.
///
/// ## Example
///
/// ```dart
/// AdaptiveScaffold(
///   items: [
///     NavigationItem(
///       name: 'Home',
///       icon: Icon(Icons.home),
///       page: HomePage(),
///     ),
///     NavigationItem(
///       name: 'Search',
///       icon: Icon(Icons.search),
///       page: SearchPage(),
///     ),
///     NavigationItem(
///       name: 'Settings',
///       icon: Icon(Icons.settings),
///       page: SettingsPage(),
///     ),
///   ],
///   initialIndex: 0,
///   aspectRatioThreshold: 1.2,
///   floatingActionButton: FloatingActionButton(
///     onPressed: () {},
///     child: Icon(Icons.add),
///   ),
/// )
/// ```
class AdaptiveScaffold extends StatefulWidget {
  /// Creates an adaptive scaffold.
  ///
  /// The [items] parameter is required and must contain at least one item.
  /// The [initialIndex] must be a valid index within [items].
  const AdaptiveScaffold({
    required this.items,
    this.initialIndex = 0,
    this.aspectRatioThreshold = 1.2,
    this.heightThresholdForLabels = 600,
    this.maxBottomNavigationItems = 4,
    this.floatingActionButton,
    this.drawerTitle,
    this.onDestinationSelected,
    this.appBar,
    this.railLeading,
    this.railTrailing,
    super.key,
  });

  /// The list of navigation items to display.
  ///
  /// Each [NavigationItem] defines a navigation destination with:
  /// - A name (label text)
  /// - An icon widget
  /// - A page widget to display when selected
  final List<NavigationItem> items;

  /// The initial selected index. Defaults to 0.
  ///
  /// This determines which navigation item is selected when the widget
  /// is first built. Must be a valid index within [items].
  final int initialIndex;

  /// The aspect ratio threshold to switch between bottom and side navigation.
  ///
  /// The aspect ratio is calculated as `width / height`.
  /// - If `aspectRatio >= threshold`: Uses [NavigationRail] (side navigation)
  /// - If `aspectRatio < threshold`: Uses [NavigationBar] (bottom navigation)
  ///
  /// Defaults to 1.2, which means landscape-ish layouts (wider than tall)
  /// will use side navigation, while portrait layouts use bottom navigation.
  final double aspectRatioThreshold;

  /// The height threshold for showing labels in portrait mode.
  ///
  /// When in portrait mode (bottom navigation) and the screen height is below
  /// this threshold, the navigation labels will be hidden to save space.
  ///
  /// Defaults to 600 pixels. Set to 0 to always show labels, or to a very
  /// high value to always hide labels in portrait mode.
  final double heightThresholdForLabels;

  /// Maximum number of navigation items to display in bottom navigation.
  ///
  /// In portrait mode (when aspect ratio < [aspectRatioThreshold]), if the
  /// number of [items] exceeds this value, a [Drawer] menu will be used
  /// instead of the bottom [NavigationBar]. The drawer can be opened via
  /// a menu button in the app bar.
  ///
  /// Defaults to 4. This prevents overcrowding in bottom navigation on
  /// mobile devices.
  final int maxBottomNavigationItems;

  /// An optional floating action button.
  ///
  /// This button will be displayed in both navigation layouts
  /// (bottom and side navigation).
  final Widget? floatingActionButton;

  /// The heading shown in the [Drawer] header.
  ///
  /// Only used when the drawer layout is active (see
  /// [maxBottomNavigationItems]). Defaults to no header at all, so nothing
  /// untranslated is ever shown — pass a localized string to display one.
  final String? drawerTitle;

  /// Called whenever the user selects a different destination.
  ///
  /// The scaffold still manages the selection itself; this is only a
  /// notification, e.g. for analytics or to sync external state.
  final ValueChanged<int>? onDestinationSelected;

  /// App bar shown in every layout.
  ///
  /// Without this, only the drawer layout gets an app bar, so resizing the
  /// window makes one appear and disappear. Provide one to keep the chrome
  /// stable across layouts; the drawer layout falls back to an app bar titled
  /// with the current destination when this is null.
  final PreferredSizeWidget? appBar;

  /// Widget shown above the destinations in the [NavigationRail].
  final Widget? railLeading;

  /// Widget shown below the destinations in the [NavigationRail].
  final Widget? railTrailing;

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    assert(widget.items.isNotEmpty, 'items must contain at least one item');
    _selectedIndex = _clampIndex(widget.initialIndex);
  }

  @override
  void didUpdateWidget(AdaptiveScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the selection valid if the items list shrinks.
    _selectedIndex = _clampIndex(_selectedIndex);
  }

  /// Clamps [index] into range, tolerating an empty [AdaptiveScaffold.items].
  ///
  /// `clamp(0, -1)` throws, so an empty list would take down the whole app in
  /// release builds where the `assert` is stripped.
  int _clampIndex(int index) {
    if (widget.items.isEmpty) return 0;
    return index.clamp(0, widget.items.length - 1);
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.onDestinationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Scaffold(
        appBar: widget.appBar,
        body: const SizedBox.shrink(),
        floatingActionButton: widget.floatingActionButton,
      );
    }

    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final aspectRatio = size.width / size.height;
    final useRail = aspectRatio >= widget.aspectRatioThreshold;
    final useDrawer =
        !useRail && widget.items.length > widget.maxBottomNavigationItems;

    // Every page is kept alive in an IndexedStack so switching destinations
    // preserves each page's state (scroll offset, form input, ...) instead of
    // rebuilding it from scratch.
    final body = IndexedStack(
      index: _selectedIndex,
      children: widget.items.map((item) => item.page).toList(),
    );

    if (useRail) {
      // Use NavigationRail for wider/landscape layouts
      return Scaffold(
        appBar: widget.appBar,
        body: Row(
          children: [
            NavigationRail(
              destinations: widget.items
                  .map(
                    (item) => NavigationRailDestination(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: Text(item.name),
                    ),
                  )
                  .toList(),
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              leading: widget.railLeading,
              trailing: widget.railTrailing,
            ),
            VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: widget.floatingActionButton,
      );
    }

    if (useDrawer) {
      final drawerTitle = widget.drawerTitle;
      // Use Drawer for portrait layouts with many items
      return Scaffold(
        appBar:
            widget.appBar ??
            AppBar(title: Text(widget.items[_selectedIndex].name)),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (drawerTitle != null)
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                  ),
                  child: Text(
                    drawerTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ...widget.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final selected = _selectedIndex == index;
                return ListTile(
                  leading: selected
                      ? item.selectedIcon ?? item.icon
                      : item.icon,
                  title: Text(item.name),
                  selected: selected,
                  onTap: () {
                    _onDestinationSelected(index);
                    Navigator.pop(context); // Close drawer
                  },
                );
              }),
            ],
          ),
        ),
        body: body,
        floatingActionButton: widget.floatingActionButton,
      );
    }

    // Use BottomNavigationBar for taller/portrait layouts
    return Scaffold(
      appBar: widget.appBar,
      body: body,
      bottomNavigationBar: NavigationBar(
        destinations: widget.items
            .map(
              (item) => NavigationDestination(
                icon: item.icon,
                selectedIcon: item.selectedIcon,
                tooltip: item.tooltip,
                label: item.name,
              ),
            )
            .toList(),
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        labelBehavior: size.height < widget.heightThresholdForLabels
            ? NavigationDestinationLabelBehavior.alwaysHide
            : NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
