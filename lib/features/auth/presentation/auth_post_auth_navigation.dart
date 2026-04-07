import 'package:flutter/material.dart';

import '../application/auth_service_contract.dart';
import '../data/models/auth_user.dart';
import '../../home/presentation/pages/landing_page.dart';
import '../../partnerships/application/partnership_invite_link_store.dart';
import '../../partnerships/application/partnership_service.dart';
import '../../partnerships/presentation/pages/accept_partnership_invite_page.dart';

Route<void> buildPostAuthRoute(Widget child) {
  return PageRouteBuilder<void>(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<void> openPostAuthDestination({
  required BuildContext context,
  required AuthServiceContract authService,
  required AuthUser user,
  bool clearStack = false,
}) async {
  final pendingInviteToken = await PartnershipInviteLinkStore.instance
      .takePendingInviteToken();

  if (!context.mounted) {
    return;
  }

  final destination = pendingInviteToken == null
      ? LandingPage(authService: authService, user: user)
      : AcceptPartnershipInvitePage(
          currentUser: user,
          partnershipService: PartnershipService.createDefault(),
          initialInviteValue: pendingInviteToken,
          workspaceBuilder: (_) =>
              LandingPage(authService: authService, user: user),
        );

  final route = buildPostAuthRoute(destination);

  if (clearStack) {
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(route, (route) => false);
    return;
  }

  if (!context.mounted) {
    return;
  }

  Navigator.of(context).pushReplacement(route);
}
