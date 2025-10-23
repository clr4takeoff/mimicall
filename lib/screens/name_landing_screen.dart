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
  bool _showError = false;

  void _saveName() async {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() => _showError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이름을 입력해주세요.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
      backgroundColor: const Color(0xFFF3F7FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '아동의 이름을 입력해주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF37474F),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '입력하신 이름은 캐릭터가 아이를 부를 때 사용돼요 😊',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 40),

              // 이름 입력창
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  hintText: '예: 지우, 수지, 에스더',
                  hintStyle: TextStyle(
                    color: Colors.grey.withOpacity(0.8),
                    fontSize: 18,
                  ), fillColor: Colors.white,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: _showError
                          ? Colors.redAccent
                          : Colors.lightBlueAccent,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: _showError ? Colors.redAccent : Colors.blueAccent,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (_) {
                  if (_showError) setState(() => _showError = false);
                },
              ),

              // 오류 메시지
              if (_showError)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    '이름을 입력해야 진행할 수 있습니다.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
                ),

              const SizedBox(height: 40),

              // 시작 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveName,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 3,
                  ),
                  child: const Text(
                    '시작하기',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
