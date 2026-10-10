import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/srs_service.dart';

void main() {
  group('SrsService - Hard phat nang hon (muc Vua)', () {
    final srs = SrsService();

    test('Hard 30d -> cap 7d, ease -0.2, giu streak, +1 lapse', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityHard,
        currentInterval: 30,
        easeFactor: 2.5,
        correctStreak: 5,
        reviewCount: 10,
      );

      expect(r.newInterval, 7);
      expect(r.newEaseFactor, closeTo(2.3, 0.0001));
      expect(r.newCorrectStreak, 5);
      expect(r.newLapseCount, 1);
    });

    test('Hard 60d -> cap 7d', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityHard,
        currentInterval: 60,
        easeFactor: 2.5,
        correctStreak: 5,
        reviewCount: 10,
      );

      expect(r.newInterval, 7);
      expect(r.newLapseCount, 1);
    });

    test('Hard 10d -> 3d, khong +lapse', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityHard,
        currentInterval: 10,
        easeFactor: 2.5,
        correctStreak: 5,
        reviewCount: 10,
      );

      expect(r.newInterval, 3);
      expect(r.newLapseCount, 0);
      expect(r.newCorrectStreak, 5);
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

    test('Again van reset 0d, streak 0, +1 lapse', () {
      final r = srs.calculateNextReview(
        quality: SrsService.qualityAgain,
        currentInterval: 30,
        easeFactor: 2.5,
        correctStreak: 5,
        reviewCount: 10,
      );

      expect(r.newInterval, 0);
      expect(r.newCorrectStreak, 0);
      expect(r.newLapseCount, 1);
    });
  });
}
