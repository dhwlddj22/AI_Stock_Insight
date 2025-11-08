import 'package:flutter/material.dart';

class AiReportScreen extends StatelessWidget {
  const AiReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI 투자 리포트")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // GPT API 호출 예정
          },
          child: const Text("리포트 생성하기"),
        ),
      ),
    );
  }
}
