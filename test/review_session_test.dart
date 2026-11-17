import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/srs_service.dart';

void main() {
  group('SrsService.sessionSize', () {
    test('khong co tu nao thi 0', () {
      expect(SrsService.sessionSize(0, 0), 0);
    });

    test('chan ca hai tang', () {
      expect(
        SrsService.sessionSize(100, 500),
        SrsService.sessionReviewLimit + SrsService.sessionNewLimit,
      );
    });

    test('it tu den han thi lay het, tu moi van bi chan', () {
      expect(SrsService.sessionSize(5, 500), 5 + SrsService.sessionNewLimit);
    });

    test('chi co tu den han', () {
      expect(SrsService.sessionSize(100, 0), SrsService.sessionReviewLimit);
    });
  });
}
