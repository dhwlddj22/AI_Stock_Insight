import 'package:flutter/material.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI 뉴스 분석")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(child: ListTile(title: Text("TSLA 관련 뉴스"), subtitle: Text("요약 및 감정 분석 결과 표시 예정"))),
        ],
      ),
    );
  }
}
