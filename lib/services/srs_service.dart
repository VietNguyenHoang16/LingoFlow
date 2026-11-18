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
  static const int qualityVague = 2;  // Nhận diện được nhưng chưa gợi nhớ
  static const int qualityHard = 3;   // Nhớ nhưng khó (Tăng từ 2 lên 3 để không bị reset interval)
  static const int qualityGood = 4;   // Nhớ tốt
  static const int qualityEasy = 5;   // Nhớ rất dễ

  /// Mơ hồ: hẹn 2 ngày; từ mới hẹn 1 ngày để luôn sớm hơn Good (2 ngày).
  static const int vagueInterval = 2;
  static const int vagueNewInterval = 1;

  /// Mastery levels
  static const int masteryNew = 0;
  static const int masteryLearning = 1;
  static const int masteryReviewing = 2;
  static const int masteryMastered = 3;

  /// Leech detection
  static const int leechThreshold = 3;    // 3 lần Vague/Hard yếu → đánh dấu Leech
  static const int leechMaxInterval = 4;  // Leech: interval tối đa 4 ngày
  static const double hardMultiplier = 0.5; // Hard: giảm 50% interval
  static const int hardMaxInterval = 14;  // Hard (interval>=2): trần 14 ngày
  static const int hardLapseThreshold = 14; // Hard trên từ >=14d thì +1 lapse

  /// Kiểm tra từ có phải là Leech không
  static bool isLeech(int lapseCount) => lapseCount >= leechThreshold;

  /// Tên hiển thị cho mastery levels (tiếng Việt, dùng chung toàn app)
  static String masteryName(int level) {
    switch (level) {
      case masteryNew:
        return 'Mới';
      case masteryLearning:
        return 'Đang học';
      case masteryReviewing:
        return 'Đang ôn';
      case masteryMastered:
        return 'Đã thuộc';
      default:
        return 'Không rõ';
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

    if (quality <= qualityVague) {
      // Mơ hồ: nhận diện được nhưng chưa gợi nhớ → ôn sớm hơn Good.
      newStreak = 0;
      newLapseCount = lapseCount + 1; // Tăng lapse count cho leech tracking
      // Giảm ease factor
      newEaseFactor = max(1.3, easeFactor - 0.2);
    } else {
      // Trả lời đúng (Hard, Good, Easy)
      // Hard: giữ nguyên streak để không leo mastery khi còn yếu.
      newStreak = quality == qualityHard ? correctStreak : correctStreak + 1;

      // Reset lapse count khi trả lời Good hoặc Easy
      if (quality >= qualityGood) {
        newLapseCount = 0;
      } else if (quality == qualityHard &&
          (currentInterval >= hardLapseThreshold || lapseCount > 0)) {
        // Hard trên từ đã ôn lâu (>=14d) hoặc đang yếu (đã có lapse):
        // tính 1 lapse để Hard liên tục vẫn rơi vào Leech (trần 4 ngày).
        newLapseCount = lapseCount + 1;
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
          // Hard: GIẢM 50% interval (không nhân easeFactor) + trần 14 ngày
          // để từ đã ôn lâu mà còn khó không bị hẹn quá xa.
          newInterval = max(1, (currentInterval * hardMultiplier).round());
          newInterval = min(newInterval, hardMaxInterval);
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

      // Cập nhật ease factor theo công thức SM-2. Hard chỉ chịu mức phạt gốc
      // (-0.14) chứ không phạt thêm, để Hard nhẹ hơn nhưng vẫn thấp hơn Good.
      newEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      newEaseFactor = max(1.3, newEaseFactor);
    }

    // Bốn mức luôn tăng dần: Vague < Hard < Good < Easy. Không có clamp này,
    // Vague cố định 1-2 ngày còn Hard = 50% interval cũ nên từ đã ôn lâu sẽ
    // hiện Hard 4d > Vague 2d (đảo thứ tự).
    final int cap = isLeech(newLapseCount) ? leechMaxInterval : 180;
    final int vagueI = min(
      _baseInterval(quality: qualityVague, currentInterval: currentInterval, easeFactor: easeFactor),
      cap,
    );
    final int hardI = min(
      max(_baseInterval(quality: qualityHard, currentInterval: currentInterval, easeFactor: easeFactor), vagueI + 1),
      cap,
    );
    final int goodI = min(
      max(_baseInterval(quality: qualityGood, currentInterval: currentInterval, easeFactor: easeFactor), hardI + 1),
      cap,
    );
    final int easyI = min(
      max(_baseInterval(quality: qualityEasy, currentInterval: currentInterval, easeFactor: easeFactor), goodI + 1),
      cap,
    );
    if (quality <= qualityVague) {
      newInterval = vagueI;
    } else if (quality == qualityHard) {
      newInterval = hardI;
    } else if (quality == qualityGood) {
      newInterval = goodI;
    } else {
      newInterval = easyI;
    }

    // Tính mastery level
    int newMasteryLevel = determineMasteryLevel(newInterval, newStreak);

    // Tính ngày ôn tiếp theo
    DateTime nextReview = DateTime.now().add(Duration(days: newInterval));

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

  /// Interval gốc của từng mức trước khi ép thứ tự Vague < Hard < Good < Easy.
  int _baseInterval({
    required int quality,
    required int currentInterval,
    required double easeFactor,
  }) {
    int interval;
    if (quality <= qualityVague) {
      interval = currentInterval == 0 ? vagueNewInterval : vagueInterval;
    } else if (currentInterval == 0) {
      interval = quality == qualityEasy ? 4 : (quality == qualityGood ? 2 : 1);
    } else if (currentInterval == 1) {
      interval = quality == qualityEasy ? 6 : (quality == qualityGood ? 3 : 2);
    } else if (quality == qualityHard) {
      interval =
          min(max(1, (currentInterval * hardMultiplier).round()), hardMaxInterval);
    } else {
      interval = (currentInterval * easeFactor).round();
    }
    if (quality == qualityEasy) interval = (interval * 1.3).round();
    return interval;
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
    if (!isCorrect) return qualityVague;

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
