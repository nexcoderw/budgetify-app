import 'package:hugeicons/hugeicons.dart';

enum AppLayoutSection {
  dashboard,
  income,
  expense,
  todos,
  saving,
  loans,
  profile,
}

class AppNavDestination {
  const AppNavDestination({
    required this.section,
    required this.label,
    required this.icon,
  });

  final AppLayoutSection section;
  final String label;
  final dynamic icon;
}

const List<AppNavDestination> defaultAppNavDestinations = [
  AppNavDestination(
    section: AppLayoutSection.dashboard,
    label: 'Dashboard',
    icon: HugeIcons.strokeRoundedDashboardSquare02,
  ),
  AppNavDestination(
    section: AppLayoutSection.income,
    label: 'Income',
    icon: HugeIcons.strokeRoundedMoneyReceiveCircle,
  ),
  AppNavDestination(
    section: AppLayoutSection.expense,
    label: 'Expense',
    icon: HugeIcons.strokeRoundedWallet02,
  ),
  AppNavDestination(
    section: AppLayoutSection.todos,
    label: 'Todos',
    icon: HugeIcons.strokeRoundedTaskDaily01,
  ),
  AppNavDestination(
    section: AppLayoutSection.saving,
    label: 'Saving',
    icon: HugeIcons.strokeRoundedPiggyBank,
  ),
  AppNavDestination(
    section: AppLayoutSection.loans,
    label: 'Loans',
    icon: HugeIcons.strokeRoundedWallet03,
  ),
];
