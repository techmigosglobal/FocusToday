import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/features/auth/presentation/screens/otp_verification_screen.dart';

void main() {
  Widget wrapApp(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('renders OTP input boxes', (tester) async {
    await tester.pumpWidget(
      wrapApp(
        const OTPVerificationScreen(
          phoneNumber: '9876543210',
          reqId: 'req_123',
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(5)); // 4 otp + phone edit
    expect(find.text('Enter OTP'), findsOneWidget);
  });

  testWidgets('shows inline error when verify tapped with incomplete OTP', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapApp(
        const OTPVerificationScreen(
          phoneNumber: '9876543210',
          reqId: 'req_123',
        ),
      ),
    );

    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter the complete 4-digit OTP.'), findsOneWidget);
  });
}
