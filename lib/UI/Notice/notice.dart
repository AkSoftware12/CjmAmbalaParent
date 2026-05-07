import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../utils/date_time_utils.dart';
import 'notice_detail.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  bool isLoading = false;
  List<dynamic> notices = [];

  @override
  void initState() {
    super.initState();
    noticeApi();
  }

  Future<void> noticeApi() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final studentToken = prefs.getString('token');
    final teacherToken = prefs.getString('teachertoken');
    final activeToken = studentToken ?? teacherToken;

    if (activeToken == null || activeToken.isEmpty) {
      setState(() => isLoading = false);
      _toast("No token found. Please login again.");
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(ApiRoutes.notice),
        headers: {
          'Authorization': 'Bearer $activeToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list =
        (data['notices'] ?? data['notice'] ?? data['data'] ?? []) as List;

        setState(() {
          notices = list;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        _toast("Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _toast("Error fetching notices");
      debugPrint("Notice API error: $e");
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _safeStr(dynamic v) => v == null ? "" : v.toString();

  String _cleanHtmlText(String input) {
    return input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  Widget _htmlDescription(String html) {
    html = _cleanHtmlText(html);

    html = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<div[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<ul[^>]*>|</ul>|<ol[^>]*>|</ol>',
        caseSensitive: false), '');

    final spans = <TextSpan>[];
    final regex = RegExp(
      r'(<b[^>]*>.*?<\/b>|<strong[^>]*>.*?<\/strong>|<i[^>]*>.*?<\/i>|<em[^>]*>.*?<\/em>|<u[^>]*>.*?<\/u>|[^<]+)',
      caseSensitive: false,
      dotAll: true,
    );

    for (final match in regex.allMatches(html)) {
      String part = match.group(0) ?? '';
      if (part.trim().isEmpty) {
        spans.add(TextSpan(text: part));
        continue;
      }

      FontWeight? weight;
      FontStyle? fontStyle;
      TextDecoration? decoration;

      if (RegExp(r'<b|<strong', caseSensitive: false).hasMatch(part)) {
        weight = FontWeight.w900;
      }
      if (RegExp(r'<i|<em', caseSensitive: false).hasMatch(part)) {
        fontStyle = FontStyle.italic;
      }
      if (RegExp(r'<u', caseSensitive: false).hasMatch(part)) {
        decoration = TextDecoration.underline;
      }

      part = part.replaceAll(RegExp(r'<[^>]*>'), '');

      spans.add(
        TextSpan(
          text: part,
          style: TextStyle(
            fontWeight: weight,
            fontStyle: fontStyle,
            decoration: decoration,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Colors.black.withOpacity(0.72),
          fontSize: 13.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        children: spans,
      ),
    );
  }

  bool _isImageUrl(String url) {
    final u = url.toLowerCase();
    return u.endsWith(".jpg") ||
        u.endsWith(".jpeg") ||
        u.endsWith(".png") ||
        u.endsWith(".webp") ||
        u.endsWith(".gif");
  }

  bool _isPdf(String url) => url.toLowerCase().endsWith(".pdf");

  bool _isExcel(String url) {
    final u = url.toLowerCase();
    return u.endsWith(".xls") || u.endsWith(".xlsx") || u.endsWith(".csv");
  }

  IconData _fileIcon(String url) {
    if (_isPdf(url)) return CupertinoIcons.doc_richtext;
    if (_isExcel(url)) return CupertinoIcons.table;
    return CupertinoIcons.doc;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return _toast("Invalid file url");

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _toast("Unable to open");
  }

  Future<void> _downloadFile({required String url, String? fileName}) async {
    try {
      final dio = Dio();
      final dir = await getApplicationDocumentsDirectory();

      final name = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : url.split('/').last.split('?').first;

      final savePath = "${dir.path}/$name";

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          title: Text("Downloading..."),
          content: LinearProgressIndicator(),
        ),
      );

      await dio.download(url, savePath);

      if (mounted) Navigator.of(context).maybePop();

      _toast("Downloaded: $name");
      await OpenFilex.open(savePath);
    } catch (e) {
      if (mounted) Navigator.of(context).maybePop();
      _toast("Download failed");
      debugPrint("Download error: $e");
    }
  }

  List<Map<String, String>> _parseAttachments(Map<String, dynamic> n) {
    final rawAtt = n['attachments'] ??
        n['files'] ??
        n['attachment'] ??
        n['file'] ??
        n['file_url'] ??
        n['notice_file'];

    final List<Map<String, String>> attachments = [];

    void addAttachment(dynamic a) {
      if (a == null) return;

      if (a is String) {
        final url = _safeStr(a).trim();
        if (url.isEmpty) return;

        if (url.contains(',')) {
          for (final part in url.split(',')) {
            final u = part.trim();
            if (u.isNotEmpty) {
              attachments.add({
                "url": u,
                "name": u.split('/').last.split('?').first,
              });
            }
          }
          return;
        }

        attachments.add({
          "url": url,
          "name": url.split('/').last.split('?').first,
        });
        return;
      }

      if (a is Map) {
        final url = _safeStr(
          a['url'] ?? a['file'] ?? a['path'] ?? a['file_url'],
        ).trim();

        if (url.isEmpty) return;

        final name = _safeStr(
          a['name'] ?? a['file_name'] ?? a['title'],
        ).trim();

        attachments.add({
          "url": url,
          "name": name.isNotEmpty ? name : url.split('/').last.split('?').first,
        });
      }
    }

    if (rawAtt is List) {
      for (final a in rawAtt) {
        addAttachment(a);
      }
    } else {
      addAttachment(rawAtt);
    }

    return attachments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        title: const Text(
          "Notices",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: noticeApi,
        child: isLoading
            ? _loadingList()
            : notices.isEmpty
            ? _emptyState()
            : _noticeList(),
      ),
    );
  }

  Widget _loadingList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(CupertinoIcons.bell_slash, size: 60, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                "No notices found",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                "Pull down to refresh",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noticeList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: notices.length,
      itemBuilder: (context, index) {
        final n = notices[index] as Map<String, dynamic>? ?? {};

        final title = _safeStr(n['title'] ?? n['notice_title'] ?? n['name']);
        final desc = _safeStr(n['description'] ?? n['desc'] ?? n['message']);
        final attachments = _parseAttachments(n);

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            final noticeId = _safeStr(n['id'] ?? n['notice_id']);
            if (noticeId.isEmpty) {
              _toast("Notice id not found");
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationDetailScreen(
                  noticeId: noticeId.toString(),
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  color: Colors.black.withOpacity(0.06),
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: const Color(0xFFEDEFF6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        CupertinoIcons.bell_fill,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? "Notice" : title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.time,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  AppDateTimeUtils.date(n['date']),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _htmlDescription(desc),
                ],

                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "Attachments",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  ...attachments
                      .map((a) => _attachmentTile(a['url']!, a['name']!))
                      .toList(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentTile(String url, String name) {
    final isImg = _isImageUrl(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EAF6)),
      ),
      child: Column(
        children: [
          if (isImg)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              child: CachedNetworkImage(
                imageUrl: url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.photo,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FD),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isImg ? CupertinoIcons.photo_fill : _fileIcon(url),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _miniBtn(
                    icon: CupertinoIcons.eye,
                    label: "View",
                    onTap: () => _openUrl(url),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
}