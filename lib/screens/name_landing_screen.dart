import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'main_screen.dart';
import '../utils/user_info.dart';

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
          backgroundColor: Color(0xFFFF7043),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    UserInfo.name = name;
    final now = DateTime.now();
    await _database.child('users/$name').set({
      'createdAt': now.toIso8601String(),
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MainScreen(userName: name)),
      );
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E9),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '이름을 입력해주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '입력하신 이름은 캐릭터가 아이를 부를 때 사용돼요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.brown,
                  ),
                ),
                const SizedBox(height: 50),

                // 이름 입력창
                TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFF5D4037),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '예: 지우, 수지, 에스더',
                    hintStyle: TextStyle(
                      color: Colors.brown.withOpacity(0.4),
                      fontSize: 18,
                    ),
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: _showError
                            ? Colors.redAccent
                            : const Color(0xFFFFB74D),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: _showError
                            ? Colors.redAccent
                            : const Color(0xFFFF7043),
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    if (_showError) setState(() => _showError = false);
                  },
                ),

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
                      backgroundColor: const Color(0xFFFFB74D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 2,
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
      ),
    );
  }
}
