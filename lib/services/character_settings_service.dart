import 'package:firebase_database/firebase_database.dart';
import '../models/character_settings_model.dart';

class CharacterSettingsService {
final DatabaseReference _db = FirebaseDatabase.instance.ref();

/// 설정 저장
Future<void> saveCharacterSettings({
  required String childName,
  required CharacterSettings settings,
}) async {
  final ref = FirebaseDatabase.instance
      .ref('preference/$childName/character_settings');

  // 기존 데이터 불러오기
  final snapshot = await ref.get();
  final existingData = snapshot.value as Map<dynamic, dynamic>? ?? {};

  // 기존 voiceId 유지
  final updatedData = settings.toJson();
  if ((updatedData['voiceId'] == null || updatedData['voiceId'] == '') &&
      existingData['voiceId'] != null) {
    updatedData['voiceId'] = existingData['voiceId'];
  }

  // DB 업데이트
  await ref.update(updatedData);
}



/// 설정 불러오기
Future<CharacterSettings?> loadCharacterSettings(String childName) async {
final ref = _db.child('preference/$childName/character_settings');
final snapshot = await ref.get();

if (!snapshot.exists) return null;

final data = Map<String, dynamic>.from(snapshot.value as Map);
return CharacterSettings.fromJson(data);
}
}
