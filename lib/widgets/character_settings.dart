import 'package:flutter/material.dart';
import '../models/character_settings_model.dart';
import 'package:image_picker/image_picker.dart';
import '../services/character_settings_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;


class CharacterSettingsDialog extends StatefulWidget {
  final String childName;

  const CharacterSettingsDialog({
    super.key,
    required this.childName,
  });

  @override
  State<CharacterSettingsDialog> createState() =>
      _CharacterSettingsDialogState();
}

class _CharacterSettingsDialogState extends State<CharacterSettingsDialog> {
  final CharacterSettingsService _settingsService = CharacterSettingsService();

  bool _isLoading = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  CharacterSettings settings = const CharacterSettings();

  @override
  void initState() {
    super.initState();
    _loadCharacterSettings();
  }

  Future<void> _loadCharacterSettings() async {
    try {
      final savedSettings =
      await _settingsService.loadCharacterSettings(widget.childName);
      if (savedSettings != null) {
        setState(() {
          settings = savedSettings;
        });
      }
    } catch (e) {
      debugPrint('설정 불러오기 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 캐릭터 이미지 선택
  Future<void> _pickCharacterImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      final base64String = base64Encode(bytes);

      setState(() {
        settings = settings.copyWith(imageBase64: base64String);
      });

      await _settingsService.saveCharacterSettings(
        childName: widget.childName,
        settings: settings,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('캐릭터 이미지가 변경되었습니다.')),
        );
      }
    }
  }

  /// 캐릭터 이미지 삭제
  Future<void> _deleteCharacterImage() async {
    try {
      final updated = settings.copyWith(imageBase64: null);
      await _settingsService.saveCharacterSettings(
        childName: widget.childName,
        settings: updated,
      );
      if (!mounted) return;

      setState(() {
        settings = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미지가 삭제되어 기본 캐릭터로 복원되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('이미지 삭제 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  /// 음성 파일 선택
  Future<void> _pickVoiceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
      );

      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final originalName = result.files.single.name; // 원본 파일명 저장용

      final ext = result.files.single.extension ?? 'mp3';
      final safeName = Uri.encodeComponent('${DateTime.now().millisecondsSinceEpoch}.$ext');

      final ref = FirebaseStorage.instance
          .ref()
          .child('voices/${widget.childName}/$safeName');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      // DB 저장
      await FirebaseDatabase.instance
          .ref('preference/${widget.childName}/character_settings')
          .update({
        'voicePath': downloadUrl,
        'characterName': originalName,
      });

      setState(() {
        settings = settings.copyWith(
          voicePath: downloadUrl,
          characterName: originalName,
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('음성 파일 업로드 완료')));

      await _triggerVoiceClone(downloadUrl);
    } catch (e) {
      debugPrint('음성 파일 업로드 오류: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 중 오류 발생: $e')),
      );
    }
  }


  Future<void> _triggerVoiceClone(String downloadUrl) async {
    try {
      final uri = Uri.parse('https://clonevoice-7ay24up3aa-uc.a.run.app');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': widget.childName,
          'url': downloadUrl,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ ElevenLabs 클로닝 요청 완료: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클로닝 요청 완료')),
        );
      } else {
        debugPrint('❌ 클로닝 요청 실패: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클로닝 실패: ${response.body}')),
        );
      }
    } catch (e) {
      debugPrint('🔥 클로닝 요청 중 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클로닝 요청 중 오류 발생: $e')),
        );
      }
    }
  }

  /// 음성 미리듣기
  Future<void> _playVoiceFile() async {
    try {
      if (settings.voicePath.isEmpty || settings.voicePath == '기본 음성') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('재생할 음성 파일이 없습니다.')),
        );
        return;
      }

      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
        return;
      }

      await _audioPlayer.play(DeviceFileSource(settings.voicePath));
      setState(() => _isPlaying = true);

      _audioPlayer.onPlayerComplete.listen((_) {
        setState(() => _isPlaying = false);
      });
    } catch (e) {
      debugPrint('음성 재생 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음성 재생 중 오류가 발생했습니다.')),
      );
    }
  }

  /// 음성 설정 BottomSheet
  void _showVoiceBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFF7E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  '🎵 캐릭터 음성 설정',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),

                // 현재 별칭 표시
                if (settings.voicePath != '기본 음성' &&
                    settings.voicePath.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '현재 음성: ${settings.characterName.isNotEmpty ? settings.characterName : "사용자 음성"}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // 음성 파일 선택
                ListTile(
                  leading: const Icon(Icons.folder_open,
                      color: Colors.orangeAccent),
                  title: const Text('음성 파일 선택'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVoiceFile();
                  },
                ),

                // 별칭 변경 기능 추가
                if (settings.voicePath != '기본 음성' &&
                    settings.voicePath.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blueAccent),
                    title: const Text('파일명 변경'),
                    onTap: () async {
                      Navigator.pop(context);
                      final alias = await _showcharacterNameDialog(context);
                      if (alias != null && alias.isNotEmpty) {
                        setState(() {
                          settings = settings.copyWith(characterName: alias);
                        });
                        await _settingsService.saveCharacterSettings(
                          childName: widget.childName,
                          settings: settings,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('캐릭터가 "$alias"(으)로 변경되었습니다.'),
                            ),
                          );
                        }
                      }
                    },
                  ),

                // 음성 미리듣기
                ListTile(
                  leading: Icon(
                    _isPlaying
                        ? Icons.stop_circle
                        : Icons.play_circle_fill,
                    color: _isPlaying ? Colors.redAccent : Colors.green,
                  ),
                  title: Text(_isPlaying ? '재생 중지' : '미리듣기'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _playVoiceFile();
                  },
                ),

                // 음성 삭제
                if (settings.voicePath != '기본 음성' &&
                    settings.voicePath.isNotEmpty)
                  ListTile(
                    leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('현재 음성 삭제'),
                    onTap: () async {
                      Navigator.pop(context);
                      setState(() {
                        settings = settings.copyWith(
                          voicePath: '기본 음성',
                          characterName: '',
                        );
                      });
                      await _settingsService.saveCharacterSettings(
                        childName: widget.childName,
                        settings: settings,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('기본 음성으로 복원되었습니다.')),
                      );
                    },
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showcharacterNameDialog(BuildContext context) async {
    final controller = TextEditingController(text: settings.characterName);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFF7E9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('음성 파일명 변경'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '새 이름 입력',
            border: OutlineInputBorder(),
            hintText: '예: 타요, 하츄핑 등',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB74D),
            ),
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('확인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB74D)),
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFFFFF7E9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        '대화 설정',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF5D4037),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 캐릭터 이미지 설정
              ListTile(
                leading: const Icon(Icons.image, color: Color(0xFFFF8A80)),
                title: const Text('캐릭터 이미지'),
                subtitle: Text(
                  settings.imageBase64 != null
                      ? "커스텀 캐릭터가 설정되었습니다."
                      : "기본 캐릭터 사용 중",
                  style:
                  const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
              if (settings.imageBase64 != null) ...[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(settings.imageBase64!),
                      key: ValueKey(settings.imageBase64),
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _smallButton(Icons.edit, '변경',
                          Colors.orangeAccent, _pickCharacterImage),
                      const SizedBox(width: 10),
                      _smallButton(Icons.delete_outline, '삭제',
                          Colors.redAccent, _deleteCharacterImage),
                    ],
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _pickCharacterImage,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text("이미지 추가"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB74D),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
              const Divider(thickness: 0.8),

              // 캐릭터 음성 설정
              ListTile(
                leading: const Icon(Icons.record_voice_over,
                    color: Color(0xFF4FC3F7)),
                title: const Text('캐릭터 음성 설정'),
                subtitle: Text(
                  settings.voicePath == '기본 음성'
                      ? '기본 음성 사용 중'
                      : '현재: ${settings.characterName.isNotEmpty ? settings.characterName : settings.voicePath.split('/').last}',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                onTap: () => _showVoiceBottomSheet(context),
              ),
              const Divider(thickness: 0.8),

              // 대화 상황 / 목표 발화 설정
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF91b32e)),
                title: const Text('대화 상황 / 목표 발화 설정'),
                // [변경 포인트] 내용을 나열하는 대신 개수만 표시
                subtitle: Text(
                  settings.contextList.isEmpty
                      ? '설정된 세트가 없습니다.'
                      : '대화 세트 ${settings.contextList.length}개',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                onTap: () async {
                  final result = await _showContextAndTargetDialog(context);
                  if (result != null) {
                    setState(() {
                      settings = settings.copyWith(
                        contextList: result['contextList'] ?? [],
                        targetList: result['targetList'] ?? [],
                      );
                    });
                  }
                },
              ),
              const Divider(thickness: 0.8),

              // 대화 스타일
              ListTile(
                leading:
                const Icon(Icons.psychology, color: Color(0xFF8E24AA)),
                title: const Text('대화 스타일'),
                subtitle: Text(
                  _styleLabel(settings.speakingStyle),
                  style:
                  const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                onTap: () async {
                  final result = await _showSpeakingStyleDialog(context);
                  if (result != null) {
                    setState(() {
                      settings = settings.copyWith(speakingStyle: result);
                    });
                  }
                },
              ),
              const Divider(thickness: 0.8),

              // 목표 발화 횟수
              ListTile(
                leading:
                const Icon(Icons.flag_outlined, color: Color(0xFFFFB74D)),
                title: const Text('목표 발화 횟수'),
                subtitle: Text('${settings.targetSpeechCount}회'),
                onTap: () async {
                  final result = await _showNumberInputDialog(
                      context, '목표 발화 횟수', settings.targetSpeechCount);
                  if (result != null) {
                    setState(() {
                      settings =
                          settings.copyWith(targetSpeechCount: result);
                    });
                  }
                },
              ),
              const Divider(thickness: 0.8),

              // 목표 집중 시간
              ListTile(
                leading: const Icon(Icons.timer_outlined,
                    color: Color(0xFF4CAF50)),
                title: const Text('목표 집중 시간 (분)'),
                subtitle: Text('${settings.focusTime}분'),
                onTap: () async {
                  final result = await _showNumberInputDialog(
                      context, '집중 시간 (분)', settings.focusTime);
                  if (result != null) {
                    setState(() {
                      settings = settings.copyWith(focusTime: result);
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('닫기', style: TextStyle(color: Color(0xFF5D4037))),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await _settingsService.saveCharacterSettings(
                childName: widget.childName,
                settings: settings,
              );

              if (context.mounted) {
                Navigator.pop(context, settings);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('설정이 저장되었습니다.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB74D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('저장', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  /// 상황 + 목표 발화 입력 다이얼로그 (삭제 기능 보완)
  Future<Map<String, List<String>>?> _showContextAndTargetDialog(
      BuildContext context) async {
    // 1. 기존 데이터를 컨트롤러 쌍으로 변환하여 초기화
    int maxLength = settings.contextList.length > settings.targetList.length
        ? settings.contextList.length
        : settings.targetList.length;

    List<Map<String, TextEditingController>> pairs = [];

    for (int i = 0; i < maxLength; i++) {
      String ctx = i < settings.contextList.length ? settings.contextList[i] : "";
      String tgt = i < settings.targetList.length ? settings.targetList[i] : "";

      pairs.add({
        'context': TextEditingController(text: ctx),
        'target': TextEditingController(text: tgt),
      });
    }

    // 데이터가 없으면 빈 세트 하나 추가
    if (pairs.isEmpty) {
      pairs.add({
        'context': TextEditingController(),
        'target': TextEditingController(),
      });
    }

    return showDialog<Map<String, List<String>>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFFF7E9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                '대화 세트 설정',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        "상황과 그에 맞는 목표 발화를 세트로 입력해주세요.",
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pairs.length,
                        separatorBuilder: (context, index) =>
                        const Divider(height: 24),
                        itemBuilder: (context, index) {
                          // 중요: 삭제 시 텍스트 꼬임 방지를 위해 Key 추가
                          return Column(
                            key: ObjectKey(pairs[index]),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 세트 번호 및 삭제 버튼 row
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Set ${index + 1}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                  // 세트가 1개 이상일 때만 삭제 버튼 표시
                                  if (pairs.length > 1)
                                    InkWell(
                                      onTap: () {
                                        // 삭제 로직: 리스트에서 제거하고 화면 갱신
                                        setState(() {
                                          pairs.removeAt(index);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.close,
                                            size: 20, color: Colors.redAccent),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // 상황 입력
                              const Text(
                                "상황",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5D4037),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: pairs[index]['context'],
                                decoration: InputDecoration(
                                  hintText: "예: 친구가 장난감을 뺏어갔을 때",
                                  hintStyle: TextStyle(
                                      color: Colors.grey.shade400, fontSize: 13),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 목표 발화 입력
                              const Text(
                                "목표 발화",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5D4037),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: pairs[index]['target'],
                                decoration: InputDecoration(
                                  hintText: "예: 내 장난감 돌려줘",
                                  hintStyle: TextStyle(
                                      color: Colors.grey.shade400, fontSize: 13),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 세트 추가 버튼
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          pairs.add({
                            'context': TextEditingController(),
                            'target': TextEditingController(),
                          });
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline,
                          color: Color(0xFFA98D15)),
                      label: const Text(
                        "세트 추가하기",
                        style: TextStyle(color: Color(0xFFA98D15)),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF75502C),
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("취소"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB74D),
                  ),
                  child:
                  const Text("확인", style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    // 저장 로직: 현재 pairs에 남아있는 항목만 저장됨
                    List<String> newContextList = [];
                    List<String> newTargetList = [];

                    for (var pair in pairs) {
                      String c = pair['context']!.text.trim();
                      String t = pair['target']!.text.trim();

                      // 둘 중 하나라도 내용이 있으면 저장
                      if (c.isNotEmpty || t.isNotEmpty) {
                        newContextList.add(c);
                        newTargetList.add(t);
                      }
                    }

                    // 삭제된 항목은 제외되고 최종 리스트만 반환됨
                    Navigator.pop(context, {
                      'contextList': newContextList,
                      'targetList': newTargetList,
                    });
                  },
                )
              ],
            );
          },
        );
      },
    );
  }


  /// 대화 스타일 선택
  Future<String?> _showSpeakingStyleDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFF7E9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '대화 스타일 선택',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D4037),
          ),
        ),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _styleOption(
              context,
              "encouraging",
              "격려형 (예: 잘했어요!, 좋아요!)",
              const Icon(Icons.emoji_emotions, color: Colors.orangeAccent),
            ),
            const Divider(height: 1),
            _styleOption(
              context,
              "questioning",
              "질문형 (예: 그 다음엔 어떻게 됐을까?)",
              const Icon(Icons.help_outline, color: Colors.blueAccent),
            ),
            const Divider(height: 1),
            _styleOption(
              context,
              "reflective",
              "반응형 (예: 음~ 그렇구나!)",
              const Icon(Icons.chat_bubble_outline, color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 대화 스타일 버튼 위젯
  Widget _styleOption(
      BuildContext context,
      String value,
      String label,
      Icon icon,
      ) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// 숫자 입력 다이얼로그
  Future<int?> _showNumberInputDialog(
      BuildContext context, String title, int currentValue) async {
    final controller = TextEditingController(text: currentValue.toString());
    return showDialog<int>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF7E9),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration:
            const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D)),
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null) Navigator.pop(context, value);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 대화 스타일 텍스트
  String _styleLabel(String code) {
    switch (code) {
      case "encouraging":
        return "격려형 (따뜻하게 칭찬하며 유도)";
      case "questioning":
        return "질문형 (짧은 질문으로 대화 이어가기)";
      case "reflective":
        return "반응형 (공감하며 되묻기)";
      default:
        return "격려형";
    }
  }

  /// 공통 버튼 스타일
  Widget _smallButton(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 95,
      height: 36,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 18),
        label: Text(label, style: TextStyle(color: color, fontSize: 13)),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: color.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
