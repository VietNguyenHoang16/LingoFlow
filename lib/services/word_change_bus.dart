import 'dart:async';

/// Bus noi bo: bao cho cac trang biet du lieu tu da thay doi de tai lai nen.
///
/// Luat:
/// - Chi dung cho thay doi du lieu that (them/sua/xoa/on tap xong).
/// - Trang nhan duoc thi `_load...(background: true)`: giu vi tri cuon,
///   khong hien spinner, khong lam mat focus o tim kiem.
class WordChangeBus {
  static final WordChangeBus _instance = WordChangeBus._internal();
  factory WordChangeBus() => _instance;
  WordChangeBus._internal();

  final StreamController<WordChangeEvent> _controller =
      StreamController<WordChangeEvent>.broadcast();

  Stream<WordChangeEvent> get stream => _controller.stream;

  void notifyChanged([String reason = 'changed']) {
    if (_controller.isClosed) return;
    _controller.add(WordChangeEvent(reason, DateTime.now()));
  }

  Future<void> dispose() => _controller.close();
}

class WordChangeEvent {
  final String reason;
  final DateTime at;
  const WordChangeEvent(this.reason, this.at);
}
