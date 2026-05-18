import 'dart:math';

/// Kết quả tính toán SRS sau mỗi lần ôn tập
class SrsResult {
  final int newInterval;
  final double newEaseFactor;
  final int newCorrectStreak;
  final int newReviewCount;
  final int newMasteryLevel;
  final DateTime nextReviewDate;

  SrsResult({
    required this.newInterval,
    required this.newEaseFactor,
    required this.newCorrectStreak,
    required this.newReviewCount,
    required this.newMasteryLevel,
    required this.nextReviewDate,
  });
}

/// Service triển khai thuật toán SM-2 (SuperMemo 2) cho Spaced Repetition
class SrsService {
  static final SrsService _instance = SrsService._internal();
  factory SrsService() => _instance;
  SrsService._internal();

  /// Quality ratings - user tự đánh giá mức nhớ
  static const int qualityAgain = 0;  // Quên hoàn toàn
  static const int qualityHard = 3;   // Nhớ nhưng khó (Tăng từ 2 lên 3 để không bị reset interval)
  static const int qualityGood = 4;   // Nhớ tốt
  static const int qualityEasy = 5;   // Nhớ rất dễ

  /// Mastery levels
  static const int masteryNew = 0;
  static const int masteryLearning = 1;
  static const int masteryReviewing = 2;
  static const int masteryMastered = 3;

  /// Tên hiển thị cho mastery levels
  static String masteryName(int level) {
    switch (level) {
      case masteryNew:
        return 'New';
      case masteryLearning:
        return 'Learning';
      case masteryReviewing:
        return 'Reviewing';
      case masteryMastered:
        return 'Mastered';
      default:
        return 'Unknown';
    }
  }

  /// Tính toán lịch ôn tập tiếp theo theo thuật toán SM-2
  ///
  /// [quality]: 0-5, mức độ user nhớ từ
  /// [currentInterval]: khoảng cách hiện tại (ngày)
  /// [easeFactor]: hệ số dễ hiện tại (min 1.3)
  /// [correctStreak]: chuỗi trả lời đúng liên tiếp
  /// [reviewCount]: tổng số lần đã ôn
  SrsResult calculateNextReview({
    required int quality,
    required int currentInterval,
    required double easeFactor,
    required int correctStreak,
    required int reviewCount,
  }) {
    double newEaseFactor = easeFactor;
    int newInterval;
    int newStreak;
    int newReviewCount = reviewCount + 1;

    if (quality < 3) {
      // Trả lời sai (Again) → làm lại ngay (0 ngày)
      newInterval = 0;
      newStreak = 0;
      // Giảm ease factor
      newEaseFactor = max(1.3, easeFactor - 0.2);
    } else {
      // Trả lời đúng (Hard, Good, Easy)
      newStreak = correctStreak + 1;

      if (currentInterval == 0) {
        // Lần đầu ôn: Phân hóa rõ rệt hơn
        if (quality == qualityEasy) {
          newInterval = 4;
        } else if (quality == qualityGood) {
          newInterval = 2;
        } else {
          newInterval = 1;
        }
      } else if (currentInterval == 1) {
        // Lần 2: Phân hóa theo quality
        if (quality == qualityEasy) {
          newInterval = 6;
        } else if (quality == qualityGood) {
          newInterval = 3;
        } else {
          newInterval = 2;
        }
      } else {
        // Lần 3+ : interval * easeFactor
        newInterval = (currentInterval * easeFactor).round();
      }

      // Điều chỉnh interval thêm dựa trên chất lượng trả lời
      if (quality == qualityEasy) {
        // Easy: cộng thêm 30% khoảng cách
        newInterval = (newInterval * 1.3).round();
      } else if (quality == qualityHard) {
        // Hard: chỉ lấy 80% khoảng cách tính toán (giãn chậm hơn)
        newInterval = max(1, (newInterval * 0.8).round());
      }

      // Cập nhật ease factor theo công thức SM-2
      newEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      newEaseFactor = max(1.3, newEaseFactor);
    }

    // Giới hạn interval tối đa 180 ngày
    newInterval = min(newInterval, 180);

    // Tính mastery level
    int newMasteryLevel = determineMasteryLevel(newInterval, newStreak);

    // Tính ngày ôn tiếp theo
    // Nếu là Again (interval = 0) thì đặt là 1 phút sau
    DateTime nextReview = newInterval == 0
        ? DateTime.now().add(const Duration(minutes: 1))
        : DateTime.now().add(Duration(days: newInterval));

    return SrsResult(
      newInterval: newInterval,
      newEaseFactor: newEaseFactor,
      newCorrectStreak: newStreak,
      newReviewCount: newReviewCount,
      newMasteryLevel: newMasteryLevel,
      nextReviewDate: nextReview,
    );
  }

  /// Xác định mastery level dựa trên interval và streak
  int determineMasteryLevel(int intervalDays, int correctStreak) {
    if (intervalDays == 0) return masteryNew;
    if (intervalDays > 21 && correctStreak >= 5) return masteryMastered;
    if (intervalDays >= 3) return masteryReviewing;
    return masteryLearning;
  }

  /// Chuyển đổi kết quả practice (đúng/sai) thành quality score
  ///
  /// [isCorrect]: user trả lời đúng hay sai
  /// [responseTimeMs]: thời gian trả lời (ms), dùng để phân biệt Hard vs Good vs Easy
  int practiceResultToQuality(bool isCorrect, {int responseTimeMs = 5000}) {
    if (!isCorrect) return qualityAgain;

    // Dựa trên thời gian phản hồi
    if (responseTimeMs < 3000) return qualityEasy;    // < 3 giây: Easy
    if (responseTimeMs < 8000) return qualityGood;     // < 8 giây: Good
    return qualityHard;                                 // > 8 giây: Hard
  }

  /// Tính thời gian còn lại trước khi cần ôn, dạng text
  String timeUntilReview(DateTime? nextReviewDate) {
    if (nextReviewDate == null) return 'New';

    final now = DateTime.now();
    final diff = nextReviewDate.difference(now);

    if (diff.isNegative) return 'Due now!';
    if (diff.inMinutes < 60) return 'Due in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Due in ${diff.inHours}h';
    if (diff.inDays == 1) return 'Due tomorrow';
    return 'In ${diff.inDays} days';
  }

  /// Kiểm tra xem từ có cần ôn hôm nay không
  bool isDueForReview(DateTime? nextReviewDate) {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate) ||
        DateTime.now().difference(nextReviewDate).abs().inHours < 1;
  }
}
