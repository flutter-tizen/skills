// Example integration test for a Flutter-Tizen app.
//
// Run it on a connected target with:
//   flutter-tizen test integration_test/app_test.dart -d <device-id>
//
// Copy this file to `integration_test/app_test.dart` in the app and replace the
// `package:my_app/main.dart` import with the real entrypoint.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('home grid', () {
    testWidgets('D-pad moves focus and OK opens the details page', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // The first tile takes focus when the grid mounts.
      expect(_focusedKey(), const ValueKey<String>('tile_0'));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_focusedKey(), const ValueKey<String>('tile_1'));

      // OK arrives as `select` on some firmware and `enter` on others; a test
      // that only sends one of them passes on a single device and fails on the
      // next. Open the details page once per variant so both are asserted.
      for (final LogicalKeyboardKey okKey in <LogicalKeyboardKey>[
        LogicalKeyboardKey.select,
        LogicalKeyboardKey.enter,
      ]) {
        await tester.sendKeyEvent(okKey);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('details_page')), findsOneWidget);

        // Back must pop the route; without an explicit handler Tizen exits
        // the app.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home_grid')), findsOneWidget);
      }
    });

    testWidgets('refresh loads expected data with required privileges', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Seed a refresh response with an item absent from the initial state.
      // Replace this key with the widget displaying that item's actual data.
      final loadedItem = find.byKey(const ValueKey('loaded_item_123'));
      expect(loadedItem, findsNothing);

      await tester.tap(find.byKey(const ValueKey('refresh')));

      // Frame settling does not wait for network/plugin work. Allow up to 10s
      // for the result; a swallowed privilege error must still fail this test.
      for (var attempt = 0; attempt < 100 && loadedItem.evaluate().isEmpty; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(loadedItem, findsOneWidget, reason: 'Refresh must load the expected item');
      expect(find.byKey(const ValueKey('error_banner')), findsNothing);
    });
  });
}

/// The key of the widget currently holding primary focus.
///
/// Read through the focus node rather than `Focus.of(context)`: that resolves
/// the nearest *ancestor* focus scope, so calling it on the keyed element's own
/// context reports the parent's state. This requires the `ValueKey` to sit on
/// the `Focus` / `FocusableActionDetector` widget itself, which is the element
/// the focus node attaches to.
Key? _focusedKey() => FocusManager.instance.primaryFocus?.context?.widget.key;
