import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/quote_service.dart';
import '../../providers/favorites_provider.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _controller = TextEditingController();
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // 새로고침 트리거용
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _seedDefaultsOnce();
    // Firestore 실시간 동기화
    FirestoreService.favoritesStream(_uid).listen((list) {
      if (mounted) context.read<FavoritesProvider>().setAll(list);
    });
  }

  // 앱 첫 실행 시 기본 심볼 채워두기 (AAPL, TSLA, PLTR)
  Future<void> _seedDefaultsOnce() async {
    final has = await FirestoreService.fetchFavorites(_uid);
    if (has.isEmpty) {
      for (final s in ['AAPL', 'TSLA', 'PLTR']) {
        await FirestoreService.addFavorite(_uid, s);
      }
    }
  }

  /// 입력값 검증 + 중복방지 + 추가
  Future<void> _add() async {
    final raw = _controller.text;
    final symbol = raw.trim().toUpperCase();

    // 영문 + 점(.)만 허용 (예: BRK.B). 필요하면 '-'도 허용 가능.
    final isValid = RegExp(r'^[A-Z.]{1,10}$').hasMatch(symbol);
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('심볼 형식이 올바르지 않습니다. 예: AAPL, TSLA, PLTR')),
      );
      return;
    }

    // 중복 방지
    final exists = context
        .read<FavoritesProvider>()
        .symbols
        .map((e) => e.toUpperCase())
        .contains(symbol);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$symbol 은(는) 이미 추가되어 있습니다.')),
      );
      _controller.clear();
      return;
    }

    try {
      await FirestoreService.addFavorite(_uid, symbol);
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추가 중 오류: $e')),
      );
    }
  }

  /// 삭제 확인 다이얼로그
  Future<bool> _confirmDelete(BuildContext context, String symbol) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('$symbol 을(를) 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    ) ??
        false;
  }

  /// 즐겨찾기 삭제(+ 되돌리기)
  Future<void> _removeFavorite(String symbol) async {
    final ok = await _confirmDelete(context, symbol);
    if (!ok) return;

    try {
      await FirestoreService.removeFavorite(_uid, symbol);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$symbol 삭제됨'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () => FirestoreService.addFavorite(_uid, symbol),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>().symbols;
    final nf = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(title: const Text('관심 종목')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: '심볼 입력 (예: AAPL, TSLA, PLTR)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _add, child: const Text('추가')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: favorites.isEmpty
                  ? const Center(child: Text('관심 종목이 없습니다. 심볼을 추가해보세요.'))
                  : RefreshIndicator(
                onRefresh: () async => setState(() => _refreshTick++), // 새로고침 트리거
                child: FutureBuilder<Map<String, dynamic>>(
                  // favorites 또는 refreshTick이 바뀌면 재호출
                  future: QuoteService.fetchQuotes(favorites)
                      .then((v) => v.map((k, q) => MapEntry(k, q))), // 타입 맞춤
                  key: ValueKey('${favorites.join(",")}|$_refreshTick'),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // 에러가 떠도 리스트는 계속 렌더 (스낵바로 알림)
                    if (snap.hasError) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('시세 조회 오류: ${snap.error}')),
                          );
                        }
                      });
                    }

                    final quotes =
                    (snap.data ?? <String, dynamic>{}) as Map<String, dynamic>;

                    return ListView.separated(
                      itemCount: favorites.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final s = favorites[index];
                        final q = quotes[s.toUpperCase()];
                        final double? price = q?.price;
                        final double? chg = q?.change;
                        final double? pct = q?.changePercent;

                        Color deltaColor;
                        if ((chg ?? 0) > 0) {
                          deltaColor = Colors.redAccent;
                        } else if ((chg ?? 0) < 0) {
                          deltaColor = Colors.blueAccent;
                        } else {
                          deltaColor = Colors.grey;
                        }

                        // 스와이프 삭제 + 아이콘 삭제 둘 다 지원
                        return Dismissible(
                          key: ValueKey(s),
                          background: Container(color: Colors.redAccent),
                          onDismissed: (_) => FirestoreService.removeFavorite(_uid, s),
                          child: Card(
                            child: ListTile(
                              title: Text(
                                s,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: price == null || !price.isFinite
                                  ? const Text('시세 불러오는 중…')
                                  : Text('현재가 ${nf.format(price)}'),
                              trailing: price == null || !price.isFinite
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${(chg ?? 0) >= 0 ? '+' : ''}${nf.format(chg ?? 0)}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: deltaColor),
                                      ),
                                      Text(
                                        (pct?.isFinite ?? false)
                                            ? '${pct!.toStringAsFixed(2)}%'
                                            : '—',
                                        style: TextStyle(color: deltaColor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: '삭제',
                                    onPressed: () => _removeFavorite(s),
                                  ),
                                ],
                              ),
                              onTap: () {
                                // TODO: 상세 화면 이동(차트/뉴스)
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
