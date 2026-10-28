import 'package:flutter_test/flutter_test.dart';
import 'package:kai_3d_seat_booking/main.dart';

void main() {
  testWidgets('KAI 3D Seat Booking Prototype smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KAI3DSeatBookingApp());
    expect(find.text('Welcome to 3D Seat Booking Prototype!'), findsOneWidget);
    expect(find.text('Start the Prototype'), findsOneWidget);
  });
}
