import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("설정")),
      body: ListView(
        children: const [
          ListTile(title: Text("환율 조회")),
          ListTile(title: Text("다크모드 전환")),
          ListTile(title: Text("로그아웃")),
        ],
      ),
    );
  }
}
