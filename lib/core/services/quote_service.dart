// lib/core/services/quote_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../models/quote.dart';

class QuoteService {
  static const String _base = 'https://api.twelvedata.com/quote';

  static Future<Map<String, Quote>> fetchQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    final key = dotenv.env['TWELVE_DATA_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('Twelve Data API 키가 비어 있습니다 (.env 확인).');
    }

    final syms = symbols.map((e) => e.toUpperCase()).join(',');
    final uri = Uri.parse('$_base?symbol=$syms&apikey=$key');

    debugPrint('[QUOTE] TD Request: $uri');

    http.Response res;
    try {
      res = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Android)',
        },
      ).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw Exception('요청 시간 초과(10s)');
    } on SocketException catch (e) {
      throw Exception('네트워크 오류: $e');
    }

    debugPrint('[QUOTE] TD Status: ${res.statusCode}');
    final preview = res.body.length > 400 ? res.body.substring(0, 400) : res.body;
    debugPrint('[QUOTE] TD Body: $preview');

    if (res.statusCode == 401) {
      throw Exception('HTTP 401: API 키 문제 또는 권한 없음 (.env 키/쿼터 확인).');
    }
    if (res.statusCode != 200) {
      throw Exception('Twelve Data 오류: HTTP ${res.statusCode}');
    }

    final decoded = json.decode(res.body);
    final out = <String, Quote>{};

    double _toD(v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? double.nan;

    Quote? _toQuote(Map<String, dynamic> j) {
      // 에러 항목 걸러내기
      if (j.containsKey('code') || j['status'] == 'error') return null;
      final symbol = (j['symbol'] ?? '').toString().toUpperCase();
      if (symbol.isEmpty) return null;

      final price = _toD(j['close']);
      final chg = j['change'] != null
          ? _toD(j['change'])
          : (j['previous_close'] != null && price.isFinite
          ? price - _toD(j['previous_close'])
          : double.nan);
      final pct = double.tryParse('${j['percent_change']}') ?? double.nan;

      return Quote(symbol: symbol, price: price, change: chg, changePercent: pct);
    }

    if (decoded is Map && decoded['data'] is List) {
      // 형식 1) { "data": [ {...}, {...} ] }
      for (final e in decoded['data'] as List) {
        final q = _toQuote(Map<String, dynamic>.from(e as Map));
        if (q != null) out[q.symbol] = q;
      }
    } else if (decoded is Map &&
        decoded.isNotEmpty &&
        decoded.values.first is Map &&
        // 형식 2) { "AAPL": {...}, "TSLA": {...} }
        (decoded.values.first as Map).containsKey('symbol')) {
      for (final entry in decoded.entries) {
        final j = Map<String, dynamic>.from(entry.value as Map);
        // 안전하게 symbol이 비어있다면 키를 대입
        j['symbol'] ??= entry.key;
        final q = _toQuote(j);
        if (q != null) out[q.symbol] = q;
      }
    } else if (decoded is Map && decoded['symbol'] != null) {
      // 형식 3) 단일 객체 { "symbol": "AAPL", ... }
      final q = _toQuote(Map<String, dynamic>.from(decoded));
      if (q != null) out[q.symbol] = q;
    } else {
      // 기타 예외 형식: 로깅만 하고 빈 맵 반환
      debugPrint('[QUOTE] Unexpected JSON shape: ${res.body}');
    }

    return out;
  }
}
