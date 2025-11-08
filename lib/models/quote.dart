class Quote {
  final String symbol;
  final double price;          // regularMarketPrice
  final double change;         // regularMarketChange
  final double changePercent;  // regularMarketChangePercent

  Quote({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePercent,
  });

  factory Quote.fromYahoo(Map<String, dynamic> j) {
    double _toD(v) => (v is num) ? v.toDouble() : double.nan;
    return Quote(
      symbol: (j['symbol'] ?? '').toString(),
      price: _toD(j['regularMarketPrice']),
      change: _toD(j['regularMarketChange']),
      changePercent: _toD(j['regularMarketChangePercent']),
    );
  }
}
