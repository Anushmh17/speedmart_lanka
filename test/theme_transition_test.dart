import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speedmart_lanka/main.dart';

void main() {
  testWidgets('Speedmart app uses animated theme transitions', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpeedmartApp()));
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedTheme), findsOneWidget);
  });
}
