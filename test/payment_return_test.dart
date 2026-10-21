import 'package:flutter_test/flutter_test.dart';
import 'package:vardhman_b2b/common/payment_return.dart';

void main() {
  group('gatewayResultOf', () {
    test('failure with a message', () {
      final result = gatewayResultOf(
        Uri.parse(
          'http://localhost:8000/?errorStatus=1&errorMessage=Payment+Failed',
        ),
      );

      expect(result?.isFailed, isTrue);
      expect(result?.errorMessage, 'Payment Failed');
    });

    test('success', () {
      final result = gatewayResultOf(
        Uri.parse(
          'https://b2b.amefird.in/vytldev/?errorStatus=0&collectResponseMessage=%7B%7D',
        ),
      );

      expect(result?.isFailed, isFalse);
      expect(result?.errorMessage, isNull);
    });

    test('unknown status counts as failed, blank message is dropped', () {
      final result = gatewayResultOf(
        Uri.parse('http://localhost:8000/?errorStatus=E05&errorMessage=+'),
      );

      expect(result?.isFailed, isTrue);
      expect(result?.errorMessage, isNull);
    });

    test('not a gateway return', () {
      expect(gatewayResultOf(Uri.parse('http://localhost:8000/')), isNull);
      expect(
        gatewayResultOf(Uri.parse('http://localhost:8000/#/open')),
        isNull,
      );
    });
  });
}
