import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'screens/name_landing_screen.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

  // SharedPreferences에서 저장된 이름 확인
  final prefs = await SharedPreferences.getInstance();
  final savedName = prefs.getString('userName');

  runApp(MyApp(savedName: savedName));
}

class MyApp extends StatelessWidget {
  final String? savedName;
  const MyApp({super.key, this.savedName});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mimicall',
      theme: ThemeData(useMaterial3: true),
      // 이름이 없으면 이름 랜딩 화면, 있으면 바로 홈으로
      home: savedName == null
          ? const NameLandingScreen()
          : MainScreen(userName: savedName),
    );
  }
}
