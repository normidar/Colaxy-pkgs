import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_helper/riverpod_helper.dart';

const _favoriteCountKey = 'colaxy_example:favorite_count';

/// Demonstrates `riverpod_helper`'s SharedPreferences-backed providers: the
/// count below survives app restarts because it's read and written through
/// [prefsAliveIntPodProvider] rather than local widget state.
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync = ref.watch(prefsAliveIntPodProvider(_favoriteCountKey));
    final notifier = ref.read(
      prefsAliveIntPodProvider(_favoriteCountKey).notifier,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: countAsync.when(
          data: (count) {
            final value = count ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'favorites_title'.tr(),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('$value', style: theme.textTheme.displayMedium),
                const SizedBox(height: 12),
                Text(
                  'favorites_body'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => notifier.setValue(value + 1),
                      icon: const Icon(Icons.add),
                      label: Text('favorites_increment_button'.tr()),
                    ),
                    OutlinedButton.icon(
                      onPressed: value == 0 ? null : notifier.removeValue,
                      icon: const Icon(Icons.refresh),
                      label: Text('favorites_reset_button'.tr()),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => RiverpodErrorView(
            widgetName: 'FavoritesPage',
            error: error,
            stackTrace: stackTrace,
          ),
        ),
      ),
    );
  }
}
