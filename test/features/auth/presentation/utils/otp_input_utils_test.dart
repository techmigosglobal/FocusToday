import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/features/auth/presentation/utils/otp_input_utils.dart';

void main() {
  group('OtpInputUtils', () {
    test('takeOtpDigits strips non-digits and caps to otpLength', () {
      expect(OtpInputUtils.takeOtpDigits('12a3-45 6789'), '1234');
      expect(OtpInputUtils.takeOtpDigits('9'), '9');
      expect(OtpInputUtils.takeOtpDigits(''), '');
    });

    test('previousIndexOnBackspace returns previous index only when valid', () {
      expect(
        OtpInputUtils.previousIndexOnBackspace(index: 3, isCurrentEmpty: true),
        2,
      );
      expect(
        OtpInputUtils.previousIndexOnBackspace(index: 0, isCurrentEmpty: true),
        isNull,
      );
      expect(
        OtpInputUtils.previousIndexOnBackspace(index: 4, isCurrentEmpty: false),
        isNull,
      );
    });

    test('shouldAutoSubmit only when 4 digits and no in-flight state', () {
      expect(
        OtpInputUtils.shouldAutoSubmit(
          otp: '1234',
          isLoading: false,
          isResending: false,
        ),
        isTrue,
      );
      expect(
        OtpInputUtils.shouldAutoSubmit(
          otp: '123',
          isLoading: false,
          isResending: false,
        ),
        isFalse,
      );
      expect(
        OtpInputUtils.shouldAutoSubmit(
          otp: '1234',
          isLoading: true,
          isResending: false,
        ),
        isFalse,
      );
      expect(
        OtpInputUtils.shouldAutoSubmit(
          otp: '1234',
          isLoading: false,
          isResending: true,
        ),
        isFalse,
      );
    });
  });
}
