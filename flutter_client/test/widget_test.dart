import 'package:flutter_test/flutter_test.dart';

import 'package:m3u_tv/main.dart';

void main() {
  testWidgets('renders the app shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // The app shell should render with the Home placeholder
    expect(find.text('Home'), findsAtLeast(1));
  });
}
