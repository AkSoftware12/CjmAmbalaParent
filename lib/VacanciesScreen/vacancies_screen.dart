import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';

/// ===============================
/// MODEL
/// ===============================
class Vacancy {
  final int id;
  final String title;
  final String? department;
  final String? location;
  final String? employmentType;
  final String? salaryRange;
  final String? lastDate;
  final String? description;
  final String? requirements;

  Vacancy({
    required this.id,
    required this.title,
    this.department,
    this.location,
    this.employmentType,
    this.salaryRange,
    this.lastDate,
    this.description,
    this.requirements,
  });

  factory Vacancy.fromJson(Map<String, dynamic> json) {
    return Vacancy(
      id: json['id'] ?? 0,
      title: (json['title'] ?? 'Untitled').toString(),
      department: _clean(json['department']),
      location: _clean(json['location']),
      employmentType: _clean(json['employment_type']),
      salaryRange: _clean(json['salary_range']),
      lastDate: _clean(json['last_date']),
      description: _clean(json['description']),
      requirements: _clean(json['requirements']),
    );
  }

  /// null ya empty string dono ko null treat karo
  static String? _clean(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Messy HTML → clean plain text
  static String? htmlToPlain(String? html) {
    if (html == null) return null;
    var text = html
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '') // HTML comments
        .replaceAll(RegExp(r'<a[^>]*>.*?</a>', dotAll: true), '') // links
        .replaceAll(RegExp(r'<[^>]*>'), '') // baaki tags
        .replaceAll(RegExp(r'\[[\d,\s]*\]'), '') // [1, 2, 3] citations
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? null : text;
  }

  String? get plainDescription => htmlToPlain(description);
  String? get plainRequirements => htmlToPlain(requirements);

  /// "2026-07-12T18:30:00.000000Z" → "14-07-2026" (dd-MM-yyyy)
  String? get formattedLastDate {
    if (lastDate == null) return null;
    final dt = DateTime.tryParse(lastDate!)?.toLocal();
    if (dt == null) return null;
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd-$mm-${dt.year}';
  }

  /// Last date nikal chuki hai kya?
  bool get isClosed {
    if (lastDate == null) return false;
    final dt = DateTime.tryParse(lastDate!);
    if (dt == null) return false;
    return DateTime.now().isAfter(dt);
  }

  /// "20000" → "₹20,000"
  String? get formattedSalary {
    if (salaryRange == null) return null;
    final n = int.tryParse(salaryRange!.replaceAll(RegExp(r'[^\d]'), ''));
    if (n == null) return salaryRange;
    final s = n.toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    parts.insert(0, rest);
    return '₹${parts.join(',')},$last3';
  }
}

/// ===============================
/// API SERVICE
/// ===============================
class VacancyService {


  /// SharedPreferences se token nikalo
  /// Pehle teacher token check karo, nahi mila to parent token
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final teacherToken = prefs.getString('teachertoken');
    if (teacherToken != null && teacherToken.isNotEmpty) {
      return teacherToken;
    }
    final parentToken = prefs.getString('token');
    if (parentToken != null && parentToken.isNotEmpty) {
      return parentToken;
    }
    return null; // dono me se koi nahi mila
  }

  /// Screen open hote hi ye hit hoga
  static Future<void> resetVacancy() async {
    try {
      final token = await _getToken();
      if (token == null) {
        debugPrint('reset-vacancy skipped: token not found');
        return;
      }

      final response = await http.post(
        Uri.parse(ApiRoutes.resetVacancies),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('reset-vacancy success: ${response.body}');
      } else {
        debugPrint('reset-vacancy failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('reset-vacancy error: $e');
    }
  }


  static Future<List<Vacancy>> fetchVacancies() async {
    final response = await http.get(Uri.parse(ApiRoutes.getVacancies));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        return (body['data'] as List)
            .map((e) => Vacancy.fromJson(e))
            .toList();
      }
      return [];
    }
    throw Exception('Failed to load vacancies');
  }
}
/// ===============================
/// VACANCIES SCREEN
/// ===============================
class VacanciesScreen extends StatefulWidget {
  const VacanciesScreen({super.key});

  @override
  State<VacanciesScreen> createState() => _VacanciesScreenState();
}

class _VacanciesScreenState extends State<VacanciesScreen> {
  late Future<List<Vacancy>> _future;

  @override
  void initState() {
    super.initState();
    VacancyService.resetVacancy(); // 👈 screen open hote hi token ke saath hit
    _future = VacancyService.fetchVacancies();
  }

  Future<void> _refresh() async {
    setState(() => _future = VacancyService.fetchVacancies());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primary,
        title: Text(
          'Vacancies',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textwhite,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: FutureBuilder<List<Vacancy>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [_ErrorView(onRetry: _refresh)],
              );
            }

            final vacancies = snapshot.data ?? [];

            if (vacancies.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [_EmptyView()],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
              itemCount: vacancies.length,
              itemBuilder: (context, index) {
                final v = vacancies[index];
                return _VacancyCard(
                  vacancy: v,
                  onApply: () => _onApply(v),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _onApply(Vacancy v) async {
    if (v.isClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: const Text('Applications for this position are closed.'),
        ),
      );
      return;
    }

    final Uri url = Uri.parse('https://cjmambala.co.in/careers');

    try {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication, // Chrome/Safari/default browser
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the careers page.'),
        ),
      );
    }
  }}

/// ===============================
/// VACANCY CARD
/// ===============================
class _VacancyCard extends StatelessWidget {
  final Vacancy vacancy;
  final VoidCallback onApply;

  const _VacancyCard({
    required this.vacancy,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final v = vacancy;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.textwhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(width: 1.sp,color: Colors.grey.shade300),
        // border: Border(
        //   left: BorderSide(color: AppColors.primary, width: 2),
        //   right: BorderSide(color: AppColors.primary, width: 2),
        //
        // ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: department chip + closed badge
            Row(
              children: [
                if (v.department != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      v.department!,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                const Spacer(),
                if (v.isClosed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child:  Text(
                      'CLOSED',
                      style: TextStyle(
                        color: AppColors.grey,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              v.title,
              style:  TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textblack,
                height: 1.25,
              ),
            ),

            // Description — null ho to show hi nahi hoga
            if (v.plainDescription != null) ...[
              const SizedBox(height: 8),
              Text(
                v.plainDescription!,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.black,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Description — null ho to show hi nahi hoga
            if (v.plainRequirements != null) ...[
              const SizedBox(height: 8),
              Text(
                v.plainRequirements!,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.black,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Info chips — null fields skip
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (v.location != null)
                  _infoChip(Icons.location_on_outlined, v.location!),
                if (v.employmentType != null)
                  _infoChip(Icons.work_outline_rounded, v.employmentType!),
                if (v.formattedSalary != null)
                  _infoChip(Icons.currency_rupee_rounded, v.formattedSalary!),
                if (v.formattedLastDate != null)
                  _infoChip(Icons.event_outlined,
                      'Last date: ${v.formattedLastDate}'),
              ],
            ),

            const SizedBox(height: 16),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: v.isClosed ? null : onApply,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  v.isClosed ? 'Closed' : 'Apply now',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textwhite,
                  disabledBackgroundColor: AppColors.grey.withOpacity(0.3),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style:  TextStyle(
              fontSize: 10.sp,
              color: AppColors.textblack,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// EMPTY & ERROR STATES
/// ===============================
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Icon(Icons.work_off_outlined, size: 64, color: AppColors.grey),
          const SizedBox(height: 16),
          Text(
            'No openings right now',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textblack,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull down to refresh and check again',
            style: TextStyle(fontSize: 13, color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.grey),
          const SizedBox(height: 16),
          Text(
            'Couldn\'t load vacancies',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textblack,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}