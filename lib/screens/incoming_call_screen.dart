import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'in_call_screen.dart';
import '../utils/user_info.dart';
import 'dart:math';

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

    // [화면 크기 계산 및 반응형 변수 설정]
    final screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    // 위치 비율 설정
    final double textTop = screenHeight * 0.18;
    final double imageTop = screenHeight * 0.38;
    final double buttonsBottom = screenHeight * 0.1;

    // 크기 설정 (화면 크기에 비례하되 너무 커지지 않게 min 사용)
    final double nameFontSize = min(screenWidth * 0.09, 40.0); // 이름 폰트
    final double subTextFontSize = min(screenWidth * 0.045, 20.0); // 안내문 폰트
    final double characterImageHeight = screenHeight * 0.3; // 이미지 높이
    final double buttonGap = screenWidth * 0.2; // 버튼 사이 간격
    final double iconSize = min(screenWidth * 0.09, 36.0); // 아이콘 크기

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
                'assets/characters/character.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 캐릭터 이름 & 안내문
          Positioned(
            top: textTop,
            child: Column(
              children: [
                Text(
                  characterName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: nameFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  "전화가 걸려오고 있어요!",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: subTextFontSize
                  ),
                ),
              ],
            ),
          ),

          // 중앙 캐릭터 이미지
          Positioned(
            top: imageTop,
            child: imageBase64 != null
                ? Image.memory(
              base64Decode(imageBase64!),
              height: characterImageHeight,
              fit: BoxFit.contain,
            )
                : Image.asset(
              'assets/characters/character.png',
              height: characterImageHeight,
              fit: BoxFit.contain,
            ),
          ),

          // 하단 수락/거절 버튼
          Positioned(
            bottom: buttonsBottom,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: 'decline',
                  backgroundColor: Colors.redAccent,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Icon(Icons.call_end, size: iconSize),
                ),
                SizedBox(width: buttonGap),
                FloatingActionButton(
                  heroTag: 'accept',
                  backgroundColor: Colors.green,
                  onPressed: () async {
                    final userName = widget.userName ?? UserInfo.name ?? "unknown";
                    UserInfo.name = userName;
                    final dbPath = await _createReportRecord(userName);

                    if (!mounted) return;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InCallScreen(dbPath: dbPath),
                      ),
                    );
                  },
                  child: Icon(Icons.call, size: iconSize),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
