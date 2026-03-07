import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/section_elements.dart';

class SavingPage extends StatelessWidget {
  const SavingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionPanel(
      badgeLabel: 'Saving workspace',
      badgeIcon: HugeIcons.strokeRoundedPiggyBank,
      title: 'Saving',
      description:
          'Organize savings goals and monitor progress toward short and long-term plans.',
      children: [
        SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SectionMetricChip(
              icon: HugeIcons.strokeRoundedTarget01,
              label: 'Goals',
              value: 'Ready to add',
            ),
            SectionMetricChip(
              icon: HugeIcons.strokeRoundedCalendar03,
              label: 'Target dates',
              value: 'Prepared',
            ),
            SectionMetricChip(
              icon: HugeIcons.strokeRoundedAnalytics02,
              label: 'Progress view',
              value: 'Planned',
            ),
          ],
        ),
        SizedBox(height: 24),
        SectionSummaryCard(
          icon: HugeIcons.strokeRoundedCoins01,
          title: 'Upcoming focus',
          description:
              'Add goal buckets, contribution plans, and progress insights that keep savings visible and motivating.',
        ),
      ],
    );
  }
}
