import 'dart:math';

/// Kết quả tính toán SRS sau mỗi lần ôn tập
class SrsResult {
  final int newInterval;
  final double newEaseFactor;
  final int newCorrectStreak;
  final int newReviewCount;
  final int newMasteryLevel;
  final DateTime nextReviewDate;
  final int newLapseCount;

  SrsResult({
    required this.newInterval,
    required this.newEaseFactor,
    required this.newCorrectStreak,
    required this.newReviewCount,
    required this.newMasteryLevel,
    required this.nextReviewDate,
    required this.newLapseCount,
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

  /// Leech detection
  static const int leechThreshold = 3;    // 3 lần Again → đánh dấu Leech
  static const int leechMaxInterval = 4;  // Leech: interval tối đa 4 ngày
  static const double hardMultiplier = 0.5; // Hard: giảm 50% interval

  /// Kiểm tra từ có phải là Leech không
  static bool isLeech(int lapseCount) => lapseCount >= leechThreshold;

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
    int lapseCount = 0,
  }) {
    double newEaseFactor = easeFactor;
    int newInterval;
    int newStreak;
    int newReviewCount = reviewCount + 1;
    int newLapseCount = lapseCount;

    if (quality < 3) {
      // Trả lời sai (Again) → làm lại ngay (0 ngày)
      newInterval = 0;
      newStreak = 0;
      newLapseCount = lapseCount + 1; // Tăng lapse count cho leech tracking
      // Giảm ease factor
      newEaseFactor = max(1.3, easeFactor - 0.2);
    } else {
      // Trả lời đúng (Hard, Good, Easy)
      newStreak = correctStreak + 1;

      // Reset lapse count khi trả lời Good hoặc Easy
      if (quality >= qualityGood) {
        newLapseCount = 0;
      }

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
        // Lần 3+
        if (quality == qualityHard) {
          // Hard: GIẢM interval 50% (không nhân easeFactor)
          newInterval = max(1, (currentInterval * hardMultiplier).round());
        } else {
          // Good/Easy: interval * easeFactor (tăng bình thường)
          newInterval = (currentInterval * easeFactor).round();
        }
      }

      // Điều chỉnh interval thêm dựa trên chất lượng trả lời
      if (quality == qualityEasy) {
        // Easy: cộng thêm 30% khoảng cách
        newInterval = (newInterval * 1.3).round();
      }

      // Cập nhật ease factor theo công thức SM-2
      newEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      newEaseFactor = max(1.3, newEaseFactor);
    }

    // Giới hạn interval tối đa
    // Nếu từ là Leech → giới hạn tối đa leechMaxInterval (4 ngày)
    // Nếu bình thường → giới hạn tối đa 180 ngày
    if (isLeech(newLapseCount)) {
      newInterval = min(newInterval, leechMaxInterval);
    } else {
      newInterval = min(newInterval, 180);
    }

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
      newLapseCount: newLapseCount,
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
