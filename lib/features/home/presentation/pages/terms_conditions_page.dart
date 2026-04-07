import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'legal_document_page.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      badgeIcon: HugeIcons.strokeRoundedLicenseDraft,
      badgeLabel: 'Terms & conditions',
      title: 'Simple rules for using Budgetify',
      summary:
          'These terms explain what you can expect from Budgetify and what we expect from you when you use the app alone or with a partner.',
      lastUpdated: 'April 7, 2026',
      sections: [
        LegalSectionData(
          title: 'Using Budgetify',
          points: [
            'Budgetify helps you track income, expenses, savings, loans, todos, and shared financial planning.',
            'You may use the app only for lawful personal or household finance management.',
            'Using the app means you agree to these terms and any future updates posted in the app.',
          ],
        ),
        LegalSectionData(
          title: 'Your account',
          points: [
            'You are responsible for keeping your login method secure and for any activity that happens through your account.',
            'Your account details should be accurate so your records, invitations, and partner access work correctly.',
            'If you think someone accessed your account without permission, you should sign out, secure your login, and stop using shared access until the issue is resolved.',
          ],
        ),
        LegalSectionData(
          title: 'Shared finances and partners',
          points: [
            'You can invite one trusted partner to work in the same finance space with you.',
            'A partner must sign in and accept the invitation before shared access starts.',
            'Once a partnership is active, both people can view and manage the shared financial data while Budgetify still tracks who created each record.',
            'The person who invited the partner can remove the partnership at any time.',
          ],
        ),
        LegalSectionData(
          title: 'Your financial records',
          points: [
            'You remain responsible for the accuracy of the amounts, dates, notes, and schedules you save in Budgetify.',
            'Budgetify is a planning and tracking tool. It does not provide financial, legal, tax, or accounting advice.',
            'You should review important records before relying on them for business, compliance, or legal decisions.',
          ],
        ),
        LegalSectionData(
          title: 'Acceptable use',
          points: [
            'Do not use Budgetify to abuse the service, interfere with other users, upload harmful content, or attempt unauthorized access.',
            'Do not use another person’s account or send partnership invitations without a real relationship or permission.',
            'We may limit or suspend access if usage creates security, fraud, or service risk.',
          ],
        ),
        LegalSectionData(
          title: 'Availability and changes',
          points: [
            'We work to keep Budgetify available and reliable, but we cannot promise uninterrupted service at all times.',
            'Features may change, improve, or be removed as the product evolves.',
            'We may update these terms when product behavior, legal requirements, or security needs change.',
          ],
        ),
        LegalSectionData(
          title: 'Ending access',
          points: [
            'You may stop using Budgetify at any time.',
            'We may suspend or end access if these terms are seriously violated or if the service needs to be protected.',
            'If access ends, previously stored data may no longer remain available to you inside the app.',
          ],
        ),
      ],
    );
  }
}
