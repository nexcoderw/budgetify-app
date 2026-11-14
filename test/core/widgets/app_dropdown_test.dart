import 'package:ingengo/core/widgets/app_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('caps the menu height and scrolls to additional options', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppDropdown<int>(
              tooltip: 'Choose option',
              label: 'Options',
              items: [
                for (var index = 0; index < 20; index++)
                  AppDropdownItem(value: index, label: 'Option $index'),
              ],
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    final scrollView = find.byType(SingleChildScrollView);
    expect(tester.getSize(scrollView).height, lessThanOrEqualTo(300));
    await tester.drag(scrollView, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option 19'));
    await tester.pumpAndSettle();

    expect(selected, 19);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports section headings and selected options', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDropdown<String>(
            tooltip: 'Filter',
            items: const [
              AppDropdownItem.heading('Direction'),
              AppDropdownItem(value: 'all', label: 'All', selected: true),
              AppDropdownItem(value: 'sent', label: 'Sent'),
            ],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('DIRECTION'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.text('Sent'), findsOneWidget);
    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();
    expect(selected, 'sent');
  });

  testWidgets('does not open when disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDropdown<String>(
            tooltip: 'Disabled options',
            enabled: false,
            label: 'Options',
            items: const [AppDropdownItem(value: 'one', label: 'Option one')],
            onSelected: (_) => fail('Disabled menu must not select an option.'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    expect(find.text('Option one'), findsNothing);
  });
}
