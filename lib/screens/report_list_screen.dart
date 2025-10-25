import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/report_model.dart';
import '../utils/user_info.dart';
import 'report_screen.dart';
import '../widgets/app_header.dart';

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
      final userName = UserInfo.name ?? "unknown";
      final ref = FirebaseDatabase.instance.ref('reports/$userName');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data =
        snapshot.value as Map<dynamic, dynamic>;
        final List<ConversationReport> loadedReports = [];

        data.forEach((key, value) {
          if (value is Map<dynamic, dynamic>) {
            final reportData = Map<String, dynamic>.from(value);
            try {
              loadedReports.add(ConversationReport.fromJson(reportData));
            } catch (e) {
              debugPrint("Error parsing report $key: $e");
            }
          }
        });

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
      setState(() => isLoading = false);
      debugPrint("Error loading reports: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF7E9),
              Color(0xFFFFF3DC),
              Color(0xFFF7D59C),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const AppHeader(title: '지난 통화 리포트', showBackButton: true),
              Expanded(
                child: isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFB74D),
                  ),
                )
                    : reports.isEmpty
                    ? const Center(
                  child: Text(
                    '저장된 리포트가 없습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF5D4037),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final createdAt = report.createdAt;
                    final formattedDate =
                        "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} "
                        "${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}";

                    return Card(
                      color: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin:
                      const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding:
                        const EdgeInsets.all(12),
                        leading: report.imageUrl.isNotEmpty
                            ? ClipRRect(
                          borderRadius:
                          BorderRadius.circular(8),
                          child: Image.network(
                            report.imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                            : const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Color(0xFFFF7043),
                          size: 36,
                        ),
                        title: Text(
                          "${report.characterName.isNotEmpty ? report.characterName : '캐릭터'} · $formattedDate",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D4037),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        subtitle: Text(
                          report.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Color(0xFFFFB74D),
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReportScreen(report: report),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
