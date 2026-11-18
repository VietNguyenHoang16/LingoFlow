import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/srs_service.dart';

void main() {
  group('SrsService - Hard nhe vua (xem dap an roi moi nho)', () {
    final srs = SrsService();

    test('Hard 30d -> cap 14d, ease -0.14, giu streak, +1 lapse', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityHard,
        currentInterval: 30,
        easeFactor: 2.5,
        correctStreak: 5,
        reviewCount: 10,
      );

      expect(r.newInterval, 14);
      expect(r.newEaseFactor, closeTo(2.36, 0.0001));
      expect(r.newCorrectStreak, 5);
      expect(r.newLapseCount, 1);
    });

    test('Hard 60d -> cap 14d', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityHard,
        currentInterval: 60,
        easeFactor: 2.5,
        correctStreak: 5,
        reviewCount: 10,
      );

      expect(r.newInterval, 14);
      expect(r.newLapseCount, 1);
    });

    test('Hard 10d -> 5d, khong +lapse', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityHard,
        currentInterval: 10,
        easeFactor: 2.5,
        correctStreak: 5,
        reviewCount: 10,
      );

      expect(r.newInterval, 5);
      expect(r.newLapseCount, 0);
      expect(r.newCorrectStreak, 5);
    });

    test('Hard 4d -> 3d (giu Vague 2d < Hard)', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityHard,
        currentInterval: 4,
        easeFactor: 2.5,
        correctStreak: 5,
        reviewCount: 10,
      );

      expect(r.newInterval, 3);
    });

    test('Hard 3 lan lien tiep tren tu cu -> roi vao Leech (cap 4d)', () {
      var interval = 30;
      var ease = 2.5;
      var lapse = 0;
      SrsResult? last;
      for (var i = 0; i < 3; i++) {
        last = srs.calculateNextReview(
          quality: SrsService.qualityHard,
          currentInterval: interval,
          easeFactor: ease,
          correctStreak: 5,
          reviewCount: 10 + i,
          lapseCount: lapse,
        );
        interval = last.newInterval;
        ease = last.newEaseFactor;
        lapse = last.newLapseCount;
      }

      expect(lapse, 3);
      expect(SrsService.isLeech(lapse), isTrue);
      expect(last!.newInterval, lessThanOrEqualTo(4));
    });

    test('Good 30d giu nguyen: 75d, streak +1, reset lapse', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityGood,
        currentInterval: 30,
        easeFactor: 2.5,
        correctStreak: 5,
        reviewCount: 10,
        lapseCount: 2,
      );

      expect(r.newInterval, 75);
      expect(r.newCorrectStreak, 6);
      expect(r.newLapseCount, 0);
    });

    test('Vague 30d -> 2d, streak 0, +1 lapse, ease -0.2', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityVague,
        currentInterval: 30,
        easeFactor: 2.5,
        correctStreak: 5,
        reviewCount: 10,
      );

      expect(r.newInterval, 2);
      expect(r.newCorrectStreak, 0);
      expect(r.newLapseCount, 1);
      expect(r.newEaseFactor, closeTo(2.3, 0.0001));
    });

    test('Vague tu moi -> 1d (som hon Good 2d)', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityVague,
        currentInterval: 0,
        easeFactor: 2.5,
        correctStreak: 0,
        reviewCount: 0,
      );

      expect(r.newInterval, 1);
    });
  });

  group('SrsService - 4 muc luon tang dan Vague < Hard < Good < Easy', () {
    final srs = SrsService();

    int intervalFor(int quality, int currentInterval, {int lapseCount = 0}) =>
        srs
            .calculateNextReview(
              quality: quality,
              currentInterval: currentInterval,
              easeFactor: 2.5,
              correctStreak: 5,
              reviewCount: 10,
              lapseCount: lapseCount,
            )
            .newInterval;

    for (final current in [0, 1, 2, 4, 8, 30, 180]) {
      test('interval $current', () {
        final vague = intervalFor(SrsService.qualityVague, current);
        final hard = intervalFor(SrsService.qualityHard, current);
        final good = intervalFor(SrsService.qualityGood, current);
        final easy = intervalFor(SrsService.qualityEasy, current);

        expect(vague, lessThan(hard));
        expect(hard, lessThan(good));
        // Trần 180 ngày nên Good/Easy có thể bằng nhau ở từ rất già.
        expect(good, lessThanOrEqualTo(easy));
        expect(easy, lessThanOrEqualTo(180));
      });
    }

    test('leech: van khong dao thu tu', () {
      final vague = intervalFor(SrsService.qualityVague, 30, lapseCount: 3);
      final hard = intervalFor(SrsService.qualityHard, 30, lapseCount: 3);
      final good = intervalFor(SrsService.qualityGood, 30, lapseCount: 3);
      final easy = intervalFor(SrsService.qualityEasy, 30, lapseCount: 3);

      expect(vague, lessThan(hard));
      expect(hard, lessThan(good));
      expect(good, lessThanOrEqualTo(easy));
      // Vague/Hard giu trang thai leech nen bi chan 4 ngay; Good/Easy reset lapse.
      expect(hard, lessThanOrEqualTo(SrsService.leechMaxInterval));
    });
  });
}
