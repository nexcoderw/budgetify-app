
## Modified Files


- Status: Modified

git add -- "android/app/build.gradle.kts"
git commit -m "chore(android): remove partnership host placeholder"


- Status: Modified

git add -- "android/app/src/main/AndroidManifest.xml"
git commit -m "chore(android): remove partnership deep links"


- Status: Modified

git add -- "ios/Runner/Info.plist"
git commit -m "chore(ios): remove unused deep link and photo permission"


- Status: Modified

git add -- "lib/app/app.dart"
git commit -m "refactor(app): remove partnership link bootstrap"


- Status: Modified

git add -- "lib/features/auth/presentation/auth_post_auth_navigation.dart"
git commit -m "refactor(auth): open transfer workspace after login"


- Status: Modified

git add -- "lib/features/home/presentation/pages/history_page.dart"
git commit -m "style(history): apply Dart formatting"


- Status: Modified

git add -- "lib/features/home/presentation/pages/landing_page.dart"
git commit -m "refactor(home): limit workspace to transfer screens"


- Status: Modified

git add -- "lib/features/home/presentation/pages/send_money_page.dart"
git commit -m "style(send-money): apply Dart formatting"


- Status: Modified

git add -- "lib/features/home/presentation/widgets/app_bottom_nav_bar.dart"
git commit -m "style(navigation): compact bottom navigation capsule"


- Status: Modified

git add -- "lib/features/home/presentation/widgets/app_layout.dart"
git commit -m "refactor(layout): remove deleted profile navigation"


- Status: Modified

git add -- "lib/features/home/presentation/widgets/app_navbar.dart"
git commit -m "style(navigation): make header controls circular"


- Status: Modified

git add -- "linux/flutter/generated_plugin_registrant.cc"
git commit -m "chore(linux): refresh generated plugin registrant"


- Status: Modified

git add -- "linux/flutter/generated_plugins.cmake"
git commit -m "chore(linux): refresh generated plugin list"


- Status: Modified

git add -- "macos/Flutter/GeneratedPluginRegistrant.swift"
git commit -m "chore(macos): refresh generated plugin registrant"


- Status: Modified

git add -- "pubspec.lock"
git commit -m "chore(deps): refresh Flutter dependency lockfile"


- Status: Modified

git add -- "pubspec.yaml"
git commit -m "chore(deps): remove unused feature dependencies"


- Status: Modified

git add -- "README.md"
git commit -m "docs(readme): align overview with transfer scope"


- Status: Modified

git add -- "test/widget_test.dart"
git commit -m "test(home): expect send money landing screen"


- Status: Modified

git add -- "windows/flutter/generated_plugin_registrant.cc"
git commit -m "chore(windows): refresh generated plugin registrant"


- Status: Modified

git add -- "windows/flutter/generated_plugins.cmake"
git commit -m "chore(windows): refresh generated plugin list"

## Deleted Files


- Status: Deleted

git add -- "lib/features/expenses/application/expense_service.dart"
git commit -m "refactor(expenses): remove expense service"


- Status: Deleted

git add -- "lib/features/expenses/data/models/expense_entry.dart"
git commit -m "refactor(expenses): remove expense entry"


- Status: Deleted

git add -- "lib/features/expenses/data/models/expense_list_query.dart"
git commit -m "refactor(expenses): remove expense list query"


- Status: Deleted

git add -- "lib/features/expenses/data/routes/expenses_api_routes.dart"
git commit -m "refactor(expenses): remove expenses api routes"


- Status: Deleted

git add -- "lib/features/expenses/data/services/expenses_api_service.dart"
git commit -m "refactor(expenses): remove expenses api service"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/dashboard_page.dart"
git commit -m "refactor(home): remove dashboard page export"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/dashboard/dashboard_balance_card.dart"
git commit -m "refactor(home): remove dashboard balance card"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/dashboard/dashboard_bar_chart.dart"
git commit -m "refactor(home): remove dashboard bar chart"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/dashboard/dashboard_cashflow_row.dart"
git commit -m "refactor(home): remove dashboard cashflow row"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/dashboard/dashboard_category_list.dart"
git commit -m "refactor(home): remove dashboard category list"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/dashboard/dashboard_data.dart"
git commit -m "refactor(home): remove dashboard data"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/dashboard/dashboard_header.dart"
git commit -m "refactor(home): remove dashboard header"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/dashboard/dashboard_page.dart"
git commit -m "refactor(home): remove dashboard page"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/dashboard/dashboard_transactions.dart"
git commit -m "refactor(home): remove dashboard transactions"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/dashboard/dashboard_utils.dart"
git commit -m "refactor(home): remove dashboard utils"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/expense_page.dart"
git commit -m "refactor(home): remove expense page"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/income_page.dart"
git commit -m "refactor(home): remove income page"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/legal_document_page.dart"
git commit -m "refactor(home): remove legal document page"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/loan_page.dart"
git commit -m "refactor(home): remove loan page"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/privacy_policy_page.dart"
git commit -m "refactor(home): remove privacy policy page"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/profile_page.dart"
git commit -m "refactor(home): remove profile page"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/saving_page.dart"
git commit -m "refactor(home): remove saving page"


- Status: Deleted

git add -- "lib/features/home/presentation/pages/terms_conditions_page.dart"
git commit -m "refactor(home): remove terms and conditions page"


- Status: Deleted

git add -- "lib/features/home/presentation/widgets/income/add_income_dialog.dart"
git commit -m "refactor(home): remove add income dialog"


- Status: Deleted

git add -- "lib/features/home/presentation/widgets/section_elements.dart"
git commit -m "refactor(home): remove legacy section widgets"


- Status: Deleted

git add -- "lib/features/income/application/income_service.dart"
git commit -m "refactor(income): remove income service"


- Status: Deleted

git add -- "lib/features/income/data/models/income_entry.dart"
git commit -m "refactor(income): remove income entry"


- Status: Deleted

git add -- "lib/features/income/data/models/income_list_query.dart"
git commit -m "refactor(income): remove income list query"


- Status: Deleted

git add -- "lib/features/income/data/routes/income_api_routes.dart"
git commit -m "refactor(income): remove income api routes"


- Status: Deleted

git add -- "lib/features/income/data/services/income_api_service.dart"
git commit -m "refactor(income): remove income api service"


- Status: Deleted

git add -- "lib/features/loans/application/loan_service.dart"
git commit -m "refactor(loans): remove loan service"


- Status: Deleted

git add -- "lib/features/loans/data/models/loan_entry.dart"
git commit -m "refactor(loans): remove loan entry"


- Status: Deleted

git add -- "lib/features/loans/data/models/loan_list_query.dart"
git commit -m "refactor(loans): remove loan list query"


- Status: Deleted

git add -- "lib/features/loans/data/routes/loans_api_routes.dart"
git commit -m "refactor(loans): remove loans api routes"


- Status: Deleted

git add -- "lib/features/loans/data/services/loans_api_service.dart"
git commit -m "refactor(loans): remove loans api service"


- Status: Deleted

git add -- "lib/features/partnerships/application/partnership_invite_link_store.dart"
git commit -m "refactor(partnerships): remove partnership invite link store"


- Status: Deleted

git add -- "lib/features/partnerships/application/partnership_service.dart"
git commit -m "refactor(partnerships): remove partnership service"


- Status: Deleted

git add -- "lib/features/partnerships/data/models/partnership_models.dart"
git commit -m "refactor(partnerships): remove partnership models"


- Status: Deleted

git add -- "lib/features/partnerships/data/routes/partnerships_api_routes.dart"
git commit -m "refactor(partnerships): remove partnerships api routes"


- Status: Deleted

git add -- "lib/features/partnerships/data/services/partnerships_api_service.dart"
git commit -m "refactor(partnerships): remove partnerships api service"


- Status: Deleted

git add -- "lib/features/partnerships/presentation/pages/accept_partnership_invite_page.dart"
git commit -m "refactor(partnerships): remove accept partnership invite page"


- Status: Deleted

git add -- "lib/features/partnerships/presentation/pages/partners_page.dart"
git commit -m "refactor(partnerships): remove partners page"


- Status: Deleted

git add -- "lib/features/partnerships/presentation/partnership_view_utils.dart"
git commit -m "refactor(partnerships): remove partnership view utils"


- Status: Deleted

git add -- "lib/features/savings/application/saving_service.dart"
git commit -m "refactor(savings): remove saving service"


- Status: Deleted

git add -- "lib/features/savings/data/models/saving_entry.dart"
git commit -m "refactor(savings): remove saving entry"


- Status: Deleted

git add -- "lib/features/savings/data/models/saving_list_query.dart"
git commit -m "refactor(savings): remove saving list query"


- Status: Deleted

git add -- "lib/features/savings/data/routes/savings_api_routes.dart"
git commit -m "refactor(savings): remove savings api routes"


- Status: Deleted

git add -- "lib/features/savings/data/services/savings_api_service.dart"
git commit -m "refactor(savings): remove savings api service"


- Status: Deleted

git add -- "lib/features/todos/application/todo_service.dart"
git commit -m "refactor(todos): remove todo service"


- Status: Deleted

git add -- "lib/features/todos/data/models/todo_item.dart"
git commit -m "refactor(todos): remove todo item"


- Status: Deleted

git add -- "lib/features/todos/data/models/todo_list_query.dart"
git commit -m "refactor(todos): remove todo list query"


- Status: Deleted

git add -- "lib/features/todos/data/models/todo_summary.dart"
git commit -m "refactor(todos): remove todo summary"


- Status: Deleted

git add -- "lib/features/todos/data/models/todo_upload_image.dart"
git commit -m "refactor(todos): remove todo upload image"


- Status: Deleted

git add -- "lib/features/todos/data/routes/todo_api_routes.dart"
git commit -m "refactor(todos): remove todo api routes"


- Status: Deleted

git add -- "lib/features/todos/data/services/todo_api_service.dart"
git commit -m "refactor(todos): remove todo api service"


- Status: Deleted

git add -- "lib/features/todos/presentation/pages/todo_page.dart"
git commit -m "refactor(todos): remove todo page"


- Status: Deleted

git add -- "lib/features/todos/presentation/todo_utils.dart"
git commit -m "refactor(todos): remove todo utils"


- Status: Deleted

git add -- "lib/features/todos/presentation/widgets/todo_delete_dialog.dart"
git commit -m "refactor(todos): remove todo delete dialog"


- Status: Deleted

git add -- "lib/features/todos/presentation/widgets/todo_expense_dialog.dart"
git commit -m "refactor(todos): remove todo expense dialog"


- Status: Deleted

git add -- "lib/features/todos/presentation/widgets/todo_form_dialog.dart"
git commit -m "refactor(todos): remove todo form dialog"


- Status: Deleted

git add -- "lib/features/todos/presentation/widgets/todo_item_card.dart"
git commit -m "refactor(todos): remove todo item card"


- Status: Deleted

git add -- "lib/features/todos/presentation/widgets/todo_summary_card.dart"
git commit -m "refactor(todos): remove todo summary card"


- Status: Deleted

git add -- "test/features/todos/todo_utils_test.dart"
git commit -m "test(todos): remove todo utility tests"

## Final Verification

After all commits are created, confirm that the working tree is clean:

git status --short
```
Review the resulting history:

git log --oneline --decorate -91
```
