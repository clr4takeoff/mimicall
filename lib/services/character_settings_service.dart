import 'package:firebase_database/firebase_database.dart';
import '../models/character_settings_model.dart';

class CharacterSettingsService {
final DatabaseReference _db = FirebaseDatabase.instance.ref();

/// 설정 저장
Future<void> saveCharacterSettings({
required String childName,
required CharacterSettings settings,
}) async {
final ref = _db.child('preference/$childName/character_settings');
await ref.set(settings.toJson());
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
