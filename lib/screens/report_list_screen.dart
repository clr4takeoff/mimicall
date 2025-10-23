import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/report_model.dart';
import 'report_screen.dart';

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  List<ConversationReport> reports = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final ref = FirebaseDatabase.instance.ref('reports');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

        // 데이터 맵을 ConversationReport 리스트로 변환
        final loadedReports = data.entries.map((entry) {
          final Map<String, dynamic> value = Map<String, dynamic>.from(entry.value);
          return ConversationReport.fromJson(value);
        }).toList();

        // 날짜 최신순 정렬
        loadedReports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        setState(() {
          reports = loadedReports;
          isLoading = false;
        });
      } else {
        setState(() {
          reports = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint("Error loading reports: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('지난 통화 리포트')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : reports.isEmpty
          ? const Center(child: Text('저장된 리포트가 없습니다.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: report.imageUrl.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  report.imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              )
                  : const Icon(Icons.chat_bubble_outline),
              title: Text(
                "${report.createdAt.year}-${report.createdAt.month.toString().padLeft(2, '0')}-${report.createdAt.day.toString().padLeft(2, '0')}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                report.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportScreen(report: report),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
