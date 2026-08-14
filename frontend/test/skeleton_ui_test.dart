import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kreavana/widgets/skeleton/skeleton_base.dart';
import 'package:kreavana/widgets/skeleton/skeleton_list.dart';
import 'package:kreavana/widgets/skeleton/skeleton_grid.dart';
import 'package:kreavana/app/theme.dart';

void main() {
  group('Skeleton UI Tests', () {
    Widget buildTestWidget({required Widget child, Brightness brightness = Brightness.light}) {
      return MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.lightTheme : AppTheme.darkTheme,
        home: Scaffold(body: child),
      );
    }

    testWidgets('SkeletonBox renders correctly in Light Mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const SkeletonBox(width: 100, height: 50),
        brightness: Brightness.light,
      ));

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.grey.shade300);
    });

    testWidgets('SkeletonBox renders correctly in Dark Mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const SkeletonBox(width: 100, height: 50),
        brightness: Brightness.dark,
      ));

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF2D2A3E));
    });

    testWidgets('SkeletonList renders correct number of items', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const SkeletonList(itemCount: 3),
      ));

      // Each list item has 1 circle and 2 lines = 3 SkeletonBoxes per item
      expect(find.byType(SkeletonBox), findsNWidgets(9));
      expect(find.byType(SkeletonAnimator), findsOneWidget);
    });

    testWidgets('SkeletonGrid renders correct number of items', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        child: const SkeletonGrid(itemCount: 4),
      ));

      // Each grid item has 2 text lines (SkeletonBox), image is a plain container
      expect(find.byType(SkeletonBox), findsNWidgets(8));
      expect(find.byType(SkeletonAnimator), findsOneWidget);
    });

    testWidgets('State transition: loading -> content -> empty', (tester) async {
      Widget buildState(int stateIndex) {
        return buildTestWidget(
          child: Builder(
            builder: (context) {
              if (stateIndex == 0) return const SkeletonList();
              if (stateIndex == 1) return const Text('Real Content');
              if (stateIndex == 2) return const Text('Empty State');
              return const Text('Error State');
            }
          )
        );
      }

      // Loading
      await tester.pumpWidget(buildState(0));
      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.text('Real Content'), findsNothing);

      // Success with content
      await tester.pumpWidget(buildState(1));
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Real Content'), findsOneWidget);

      // Empty State
      await tester.pumpWidget(buildState(2));
      expect(find.text('Real Content'), findsNothing);
      expect(find.text('Empty State'), findsOneWidget);
      
      // Error State
      await tester.pumpWidget(buildState(3));
      expect(find.text('Empty State'), findsNothing);
      expect(find.text('Error State'), findsOneWidget);
    });
  });
}
