import '../../auth/data/models/auth_user.dart';
import '../data/models/partnership_models.dart';

String formatPartnershipDate(DateTime value) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String displayAuthUserName(AuthUser user) {
  final fullName = user.fullName?.trim();
  if (fullName != null && fullName.isNotEmpty) {
    return fullName;
  }

  final firstName = user.firstName?.trim();
  final lastName = user.lastName?.trim();
  final composed = <String>[
    if (firstName != null && firstName.isNotEmpty) firstName,
    if (lastName != null && lastName.isNotEmpty) lastName,
  ].join(' ');

  return composed.isEmpty ? user.email.split('@').first : composed;
}

String displayPartnerName(PartnerUser user) {
  final fullName = user.fullName?.trim();
  if (fullName != null && fullName.isNotEmpty) {
    return fullName;
  }

  final firstName = user.firstName?.trim();
  final lastName = user.lastName?.trim();
  final composed = <String>[
    if (firstName != null && firstName.isNotEmpty) firstName,
    if (lastName != null && lastName.isNotEmpty) lastName,
  ].join(' ');

  return composed.isEmpty ? user.email.split('@').first : composed;
}

String displayLoosePartnerName({
  String? firstName,
  String? lastName,
  String? fullName,
  required String email,
}) {
  final normalizedFullName = fullName?.trim();
  if (normalizedFullName != null && normalizedFullName.isNotEmpty) {
    return normalizedFullName;
  }

  final composed = <String>[
    if (firstName != null && firstName.trim().isNotEmpty) firstName.trim(),
    if (lastName != null && lastName.trim().isNotEmpty) lastName.trim(),
  ].join(' ');

  return composed.isEmpty ? email.split('@').first : composed;
}

String? extractInviteToken(String input) {
  final normalized = input.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(normalized);
  final token = uri?.queryParameters['token'];
  if (token != null && token.isNotEmpty) {
    return token;
  }

  return normalized.contains(' ')
      ? null
      : normalized.replaceAll(RegExp(r'^.*token='), '');
}

String? extractInviteTokenFromUri(Uri uri) {
  final pathSegments = uri.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
  final host = uri.host.trim().toLowerCase();
  final scheme = uri.scheme.trim().toLowerCase();

  final isCustomInviteRoute =
      scheme == 'budgetify' &&
      host == 'partnership' &&
      pathSegments.length == 1 &&
      pathSegments.first == 'accept';

  final isWebInviteRoute =
      pathSegments.length >= 2 &&
      pathSegments[pathSegments.length - 2] == 'partnership' &&
      pathSegments.last == 'accept';

  if (!isCustomInviteRoute && !isWebInviteRoute) {
    return null;
  }

  final queryToken = uri.queryParameters['token'];
  if (queryToken == null || queryToken.trim().isEmpty) {
    return null;
  }

  return queryToken.trim();
}
