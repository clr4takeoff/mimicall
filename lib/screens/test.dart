import 'package:flutter/material.dart';
import '/services/llm_service.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final controller = TextEditingController();
  String result = '';
  final gpt = GPTResponse();

  Future<void> sendToGPT() async {
    final res = await gpt.fetchGPTCommentResponse(controller.text);
    setState(() => result = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPT Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: controller, decoration: const InputDecoration(labelText: '내용 입력')),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: sendToGPT, child: const Text('전송')),
            const SizedBox(height: 20),
            Text(result),
          ],
        ),
      ),
    );
  }
}
