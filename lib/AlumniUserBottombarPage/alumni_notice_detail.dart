import 'dart:convert';

import 'package:avi/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/date_time_utils.dart';

class AlumniNotificationDetailScreen extends StatefulWidget {
  final String noticeId;

  const AlumniNotificationDetailScreen({
    super.key,
    required this.noticeId,
  });

  @override
  State<AlumniNotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<AlumniNotificationDetailScreen> {
  bool isLoading = false;
  Map<String, dynamic> noticeData = {};

  @override
  void initState() {
    super.initState();
    fetchNoticeById();
  }

  Future<void> fetchNoticeById() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('alumnitoken');


    try {
      final response = await http.get(
        Uri.parse("${ApiRoutes.getAlumniNotice}/${widget.noticeId}"),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // Handle both flat and nested shapes
        dynamic data = jsonData['data'] ?? jsonData;
        if (data is Map && data['notice'] is Map) {
          data = data['notice'];
        } else {
          data = jsonData['notice'] ?? jsonData['notification'] ?? data;
        }

        setState(() {
          noticeData = data is Map ? Map<String, dynamic>.from(data) : {};
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        _toast("Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _toast("Notice detail fetch failed");
      debugPrint("Notice detail error: $e");
    }
  }

  String _safeStr(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  String _title() {
    final title = _safeStr(
      noticeData['title'] ?? noticeData['notice_title'] ?? noticeData['name'],
    );
    return title.isEmpty ? "Notice" : title;
  }

  String _description() {
    final desc = _safeStr(
      noticeData['description'] ??
          noticeData['desc'] ??
          noticeData['message'] ??
          noticeData['body'],
    );

    final clean = _cleanHtmlText(desc);
    return clean.isEmpty ? "No description available" : clean;
  }

  String _date() {
    return _safeStr(
      noticeData['date'] ??
          noticeData['created_at'] ??
          noticeData['notice_date'],
    );
  }

  dynamic _attachment() {
    return noticeData['attachment'] ??
        noticeData['attach'] ??
        noticeData['file'] ??
        noticeData['file_url'] ??
        noticeData['notice_file'];
  }

  bool _hasAttachment() {
    final att = _attachment();
    return att != null && att.toString().trim().isNotEmpty;
  }

  String _cleanHtmlText(String input) {
    return input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Alumni Notice Detail',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      )
          : noticeData.isEmpty
          ? _emptyState()
          : RefreshIndicator(
        onRefresh: fetchNoticeById,
        color: AppColors.primary,
        child: ListView(
          padding: EdgeInsets.all(screenWidth * 0.04),
          children: [
            Text(
              _title(),
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 21 : 17.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                height: 1.35,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: isTablet ? 18 : 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppDateTimeUtils.date(_date()),
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 15 : 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildContentCard(
              title: 'Description',
              content: _description(),
              screenWidth: screenWidth,
              isTablet: isTablet,
            ),

            const SizedBox(height: 24),

            if (_hasAttachment()) ...[
              Text(
                'Attachments',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildAttachmentTile(
                _attachment(),
                screenWidth,
                isTablet,
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.bell_slash,
            size: 62,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 12),
          Text(
            "Notice not found",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Pull back and try again",
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard({
    required String title,
    required String content,
    required double screenWidth,
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 16 : 14,
              color: Colors.black87,
              height: 1.7,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentTile(
      dynamic attachment,
      double screenWidth,
      bool isTablet,
      ) {
    final rawUrl = attachment.toString().trim();

    String fileName = rawUrl.split('/').last.split('?').first;
    String fileType = 'FILE';
    IconData fileIcon = Icons.attachment_rounded;

    final lowerUrl = rawUrl.toLowerCase();

    if (lowerUrl.endsWith('.pdf')) {
      fileType = 'PDF';
      fileIcon = Icons.picture_as_pdf_rounded;
    } else if (lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.webp')) {
      fileType = 'IMAGE';
      fileIcon = Icons.image_rounded;
    } else if (lowerUrl.endsWith('.doc') || lowerUrl.endsWith('.docx')) {
      fileType = 'DOCUMENT';
      fileIcon = Icons.description_rounded;
    } else if (lowerUrl.endsWith('.xls') ||
        lowerUrl.endsWith('.xlsx') ||
        lowerUrl.endsWith('.csv')) {
      fileType = 'SPREADSHEET';
      fileIcon = Icons.table_chart_rounded;
    } else if (lowerUrl.endsWith('.zip') ||
        lowerUrl.endsWith('.rar') ||
        lowerUrl.endsWith('.7z')) {
      fileType = 'ARCHIVE';
      fileIcon = Icons.folder_zip_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.035,
          vertical: screenWidth * 0.02,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            fileIcon,
            color: AppColors.primary,
            size: isTablet ? 28 : 24,
          ),
        ),
        title: Text(
          fileName.isEmpty ? 'Attachment' : fileName,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            fileType,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        trailing: _miniBtn(
          icon: CupertinoIcons.eye,
          label: "View",
          onTap: () => _openUrl(rawUrl),
        ),
        onTap: () => _openUrl(rawUrl),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url.trim());

    if (uri == null || !uri.hasScheme) {
      _toast("Invalid file url");
      return;
    }

    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!ok) {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      _toast("Unable to open file");
    }
  }

  Widget _miniBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}