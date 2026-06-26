# TODO

## Step 1: Fix const/inputFormatters type errors in `creator_application_card.dart`
- Replace `static const _digitsOnly` / `_nameFormatters` with non-const or properly typed `List<TextInputFormatter>`.
- Avoid using non-const factories in const expressions (`RegExp` inside `FilteringTextInputFormatter.allow`).
- Ensure `inputFormatters` receives `List<TextInputFormatter>` (not `List<dynamic>`).

## Step 2: Fix double->int error in `dashboard_stats_charts.dart`
- Locate `final e = entries[i];` and adjust types for `i` indexing bounds/cast (likely from fl_chart callbacks where `i`/`v` are double).
- Ensure entries indexing uses `i.toInt()` consistently.

## Step 3: Validate build
- Run `flutter analyze` (and/or `flutter run`) to confirm errors are resolved.

