import 'package:flutter_test/flutter_test.dart';
import 'package:lingoflow/services/bulk_word_importer.dart';
import 'package:lingoflow/services/database_service.dart';

ImportLine line(int n, String word) => ImportLine(
  lineNumber: n,
  rawLine: word,
  word: word,
  meaning: 'nghia',
  wordType: 'noun',
);

void main() {
  test('loi retryable duoc thu lai va luu thanh cong', () async {
    var calls = 0;

    Future<BulkAddResult> fake(
      int userId,
      String category,
      List<Map<String, dynamic>> words,
    ) async {
      calls += 1;
      if (calls == 1) {
        return BulkAddResult(
          insertedCount: 0,
          failed: words
              .map(
                (word) => BulkAddFailure(
                  word: word['word'] as String,
                  message: 'AI phản hồi quá chậm. Vui lòng thử lại.',
                  retryable: true,
                ),
              )
              .toList(),
        );
      }
      return BulkAddResult(insertedCount: words.length);
    }

    final result = await BulkWordImporter().importBatch(
      1,
      [line(1, 'alpha'), line(2, 'beta')],
      bulkAdd: fake,
      pronunciationsOverride: const {'alpha': '', 'beta': ''},
    );

    expect(calls, 2);
    expect(result.insertedCount, 2);
    expect(result.failedWords, isEmpty);
  });

  test('loi khong retryable khong thu lai', () async {
    var calls = 0;

    Future<BulkAddResult> fake(
      int userId,
      String category,
      List<Map<String, dynamic>> words,
    ) async {
      calls += 1;
      return BulkAddResult(
        insertedCount: 0,
        failed: words
            .map(
              (word) => BulkAddFailure(
                word: word['word'] as String,
                message: 'API key không hợp lệ hoặc không có quyền.',
              ),
            )
            .toList(),
      );
    }

    final result = await BulkWordImporter().importBatch(
      1,
      [line(1, 'alpha')],
      bulkAdd: fake,
      pronunciationsOverride: const {'alpha': ''},
    );

    expect(calls, 1);
    expect(result.insertedCount, 0);
    expect(result.failedWords, hasLength(1));
  });

  test('retry toi da 2 luot roi bao loi', () async {
    var calls = 0;

    Future<BulkAddResult> fake(
      int userId,
      String category,
      List<Map<String, dynamic>> words,
    ) async {
      calls += 1;
      return BulkAddResult(
        insertedCount: 0,
        failed: words
            .map(
              (word) => BulkAddFailure(
                word: word['word'] as String,
                message: 'Hết thời gian tạo ví dụ.',
                retryable: true,
              ),
            )
            .toList(),
      );
    }

    final result = await BulkWordImporter().importBatch(
      1,
      [line(1, 'alpha')],
      bulkAdd: fake,
      pronunciationsOverride: const {'alpha': ''},
    );

    expect(calls, 3);
    expect(result.failedWords, hasLength(1));
  });
}
