class HomeTabHistory {
  final List<int> _entries = [0];

  int get current => _entries.last;
  bool get canExit => _entries.length == 1;

  void visit(int index) {
    if (index != current) {
      _entries.add(index);
    }
  }

  int? back() {
    if (canExit) return null;
    _entries.removeLast();
    return current;
  }
}
