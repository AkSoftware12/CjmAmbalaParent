import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class TuitionFeeCertificateScreen extends StatefulWidget {
  const TuitionFeeCertificateScreen({super.key});

  @override
  State<TuitionFeeCertificateScreen> createState() =>
      _TuitionFeeCertificateScreenState();
}

class _TuitionFeeCertificateScreenState
    extends State<TuitionFeeCertificateScreen> {
  bool isLoading = true;
  Map<String, dynamic>? feeData;

  @override
  void initState() {
    super.initState();
    fetchTuitionFee();
  }

  Future<void> fetchTuitionFee() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse(ApiRoutes.getTuitionFee),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        if (body["success"] == true && body["data"] != null) {
          feeData = Map<String, dynamic>.from(body["data"]);
        }
      }
    } catch (e) {
      debugPrint("Tuition Fee Error: $e");
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> openInBrowser(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          "Tuition Fee Certificate",
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      )
          : feeData == null
          ? const _EmptyTuitionFeeView()
          : ListView(
        padding: const EdgeInsets.all(10),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () async {
              final url = feeData!["url"]?.toString() ?? "";
              if (url.isNotEmpty) {
                openInBrowser(url);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Container(
                        height: 62,
                        width: 62,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.15),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Tuition Fee Certificate",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: .3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              feeData!["student_name"]?.toString() ?? "",
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.white.withOpacity(.95),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Total Fee : ₹${feeData!["total_tuition_fee"] ?? 0}",
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.white.withOpacity(.9),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.print_rounded,
                              color: Color(0xffe52d27),
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Print Now",
                              style: TextStyle(
                                color: Color(0xffe52d27),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _EmptyTuitionFeeView extends StatelessWidget {
  const _EmptyTuitionFeeView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.red.shade200, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.red,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "No Tuition Fee Certificate Found",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your tuition fee certificate is not available right now.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
