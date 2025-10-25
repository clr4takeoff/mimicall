import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'in_call_screen.dart';
import '../utils/user_info.dart';

class IncomingCallScreen extends StatefulWidget {
  final String? userName;

  const IncomingCallScreen({super.key, this.userName});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  String characterName = "캐릭터"; // 기본값
  String? imageBase64;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacterData();
  }

  /// Firebase에서 캐릭터 정보 불러오기
  Future<void> _loadCharacterData() async {
    try {
      final name = widget.userName ?? UserInfo.name ?? "unknown";
      final ref = FirebaseDatabase.instance
          .ref('preference/$name/character_settings');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          characterName = (data['characterName'] as String?)?.trim().isNotEmpty == true
              ? data['characterName']
              : "캐릭터";
          imageBase64 = data['imageBase64'];
        });
      }
    } catch (e) {
      debugPrint("캐릭터 정보 불러오기 실패: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 대화 리포트 기록 생성
  Future<String> _createReportRecord(String userName) async {
    final db = FirebaseDatabase.instance.ref();
    final now = DateTime.now();

    final safeKey =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final dbPath = 'reports/$userName/$safeKey';
    final reportRef = db.child(dbPath);

    await reportRef.set({
      'id': safeKey,
      'summary': '',
      'imageUrl': '',
      'imageBase64': '',
      'speechRatio': {},
      'createdAt': now.toIso8601String(),
      'conversation': [],
    });

    return dbPath;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 캐릭터 (흐릿하게)
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: imageBase64 != null
                  ? Image.memory(
                base64Decode(imageBase64!),
                fit: BoxFit.cover,
              )
                  : Image.asset(
                'assets/characters/ditto.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 캐릭터 이름 & 안내문
          Positioned(
            top: 140,
            child: Column(
              children: [
                Text(
                  characterName, // Firebase에서 가져온 캐릭터 이름 표시
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "전화가 걸려오고 있어요!",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ],
            ),
          ),

          // 중앙 캐릭터 이미지
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            child: imageBase64 != null
                ? Image.memory(
              base64Decode(imageBase64!),
              height: 200,
            )
                : Image.asset(
              'assets/characters/ditto.png',
              height: 200,
            ),
          ),

          // 하단 수락/거절 버튼
          Positioned(
            bottom: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: 'decline',
                  backgroundColor: Colors.redAccent,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.call_end, size: 36),
                ),
                const SizedBox(width: 80),
                FloatingActionButton(
                  heroTag: 'accept',
                  backgroundColor: Colors.green,
                  onPressed: () async {
                    final userName = widget.userName ?? UserInfo.name ?? "unknown";
                    UserInfo.name = userName;
                    final dbPath = await _createReportRecord(userName);

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InCallScreen(dbPath: dbPath),
                      ),
                    );
                  },
                  child: const Icon(Icons.call, size: 36),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
