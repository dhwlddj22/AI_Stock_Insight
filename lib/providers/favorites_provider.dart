import 'package:flutter/foundation.dart';

class FavoritesProvider with ChangeNotifier {
  final List<String> _symbols = [];
  List<String> get symbols => List.unmodifiable(_symbols);

  void setAll(List<String> list) {
    _symbols
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  void add(String symbol) {
    final s = symbol.trim().toUpperCase();
    if (s.isEmpty || _symbols.contains(s)) return;
    _symbols.add(s);
    notifyListeners();
  }

  void remove(String symbol) {
    _symbols.remove(symbol);
    notifyListeners();
  }
}
