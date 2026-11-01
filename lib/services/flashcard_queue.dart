class FlashcardQueue<T> {
  final List<T> _items;
  final int total;

  FlashcardQueue._(this._items, this.total);

  factory FlashcardQueue(Iterable<T> items) {
    final list = List<T>.of(items);
    return FlashcardQueue._(list, list.length);
  }

  T? get current => _items.isEmpty ? null : _items.first;

  int get remaining => _items.length;

  int get known => total - _items.length;

  bool get isDone => _items.isEmpty;

  T? markKnown() {
    if (_items.isEmpty) return null;
    return _items.removeAt(0);
  }

  void markUnknown() {
    if (_items.isEmpty) return;
    final card = _items.removeAt(0);
    _items.add(card);
  }
}
