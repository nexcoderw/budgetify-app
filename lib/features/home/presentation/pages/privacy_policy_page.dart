import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'legal_document_page.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      badgeIcon: HugeIcons.strokeRoundedShieldEnergy,
      badgeLabel: 'Privacy policy',
      title: 'How Budgetify handles your data',
      summary:
          'This policy explains what information Budgetify collects, why it is used, and how shared financial data is handled when you use the app.',
      lastUpdated: 'April 7, 2026',
      sections: [
        LegalSectionData(
          title: 'What we collect',
          points: [
            'We collect the account details needed to identify you, such as your name, email address, profile image, and login status.',
            'We collect the financial records you create in the app, including income, expenses, loans, savings, todos, notes, dates, images, and related schedules.',
            'When you use shared finances, we also store partnership details such as the inviter, the invitee email, invite status, and who created each shared record.',
          ],
        ),
        LegalSectionData(
          title: 'Why we use your information',
          points: [
            'We use your information to run the app, save your data, show your dashboard, and keep your records available across sessions.',
            'We use account and invitation details to support secure sign-in, partnership invitations, and access control.',
            'We may use service-level technical data to improve reliability, performance, and security.',
          ],
        ),
        LegalSectionData(
          title: 'How shared finances work',
          points: [
            'If you accept a partnership invitation, your partner can view and manage the same shared finance workspace.',
            'Shared records remain traceable because Budgetify stores who created each item.',
            'If a partnership ends, future access to the shared workspace changes according to the product rules in effect at that time.',
          ],
        ),
        LegalSectionData(
          title: 'When we share data',
          points: [
            'We do not share your personal financial records with other users unless you choose to create or join a shared partnership inside Budgetify.',
            'We may rely on service providers that help operate hosting, authentication, storage, email delivery, and related infrastructure.',
            'We may disclose information when required to comply with law, enforce product rules, or protect users and the service.',
          ],
        ),
        LegalSectionData(
          title: 'Storage and security',
          points: [
            'We use reasonable safeguards to protect your account and stored records, but no system can guarantee absolute security.',
            'You also play a role in protecting your data by securing your device and login method.',
            'If you use shared finances, you should invite only someone you trust with the same level of visibility you will receive into that workspace.',
          ],
        ),
        LegalSectionData(
          title: 'Your choices',
          points: [
            'You can update or delete many records directly inside the app.',
            'You can remove a partner relationship if you are the inviter and no longer want to share the same workspace.',
            'You can stop using the app at any time, but some operational or legal records may remain in backups or logs for a limited period.',
          ],
        ),
        LegalSectionData(
          title: 'Policy updates',
          points: [
            'We may update this policy when product features, legal duties, or data practices change.',
            'When updates matter to your use of the service, the latest version will appear in the app.',
            'Continuing to use Budgetify after an update means the new policy will apply going forward.',
          ],
        ),
      ],
    );
  }
}
