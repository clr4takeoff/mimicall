import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'main_screen.dart';

class NameLandingScreen extends StatefulWidget {
  const NameLandingScreen({Key? key}) : super(key: key);

  @override
  State<NameLandingScreen> createState() => _NameLandingScreenState();
}

class _NameLandingScreenState extends State<NameLandingScreen> {
  final _controller = TextEditingController();
  final _database = FirebaseDatabase.instance.ref();

  void _saveName() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final now = DateTime.now();
    final formattedId =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}_${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}';

    await _database.child('users/$formattedId').set({
      'name': name,
      'createdAt': now.toIso8601String(),
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainScreen(userName: name)),
      );
    }
  }
  String _twoDigits(int n) => n.toString().padLeft(2, '0');


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('안녕! 너의 이름을 알려줄래?', style: TextStyle(fontSize: 24, color: Colors.white)),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '이름 입력',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveName,
                child: const Text('시작하기'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
