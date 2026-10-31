import 'package:budgetify/features/financial_messages/data/models/financial_message_pilot_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses privacy-safe pilot metrics', () {
    final summary = FinancialMessagePilotSummary.fromJson({
      'mode': 'pilot',
      'windowDays': 30,
      'total': 12,
      'pending': 3,
      'confirmed': 8,
      'dismissed': 1,
      'needsReview': 2,
      'possibleDuplicates': 1,
      'health': 'HEALTHY',
      'lastImportAt': '2026-10-31T08:00:00.000Z',
      'providers': [
        {
          'providerCode': 'MTN_MOMO_RW',
          'label': 'MTN MoMo',
          'enabled': true,
          'total': 12,
          'parsed': 10,
          'needsReview': 2,
          'confirmed': 8,
          'parseRatePercent': 83,
          'readiness': 'MONITORING',
        },
      ],
      'isTruncated': false,
      'currentShortcutVersion': 2,
      'minimumShortcutVersion': 2,
      'shortcutInstallUrl': 'https://www.icloud.com/shortcuts/test',
      'legacyShortcutImports': 1,
      'outdatedShortcutImports': 2,
    });

    expect(summary.health, FinancialMessagePilotHealth.healthy);
    expect(summary.providers.single.label, 'MTN MoMo');
    expect(summary.providers.single.enabled, isTrue);
    expect(summary.possibleDuplicates, 1);
    expect(summary.hasOutdatedShortcuts, isTrue);
    expect(
      summary.providers.single.readiness,
      FinancialMessageProviderReadiness.monitoring,
    );
  });
}
