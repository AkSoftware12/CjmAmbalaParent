import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';

// ✅ apna AppColors wala import lagao (aapke project me already hai)
/// import 'package:your_app/utils/app_colors.dart';

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

    // ✅ jo token mile wahi use hoga
    final activeToken = studentToken ?? teacherToken;

    if (activeToken == null || activeToken.isEmpty) {
      setState(() => isLoading = false);
      _toast("No token found. Please login again.");
      return;
    }

    try {
      final url = Uri.parse(ApiRoutes.notice);

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $activeToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ flexible keys handle
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

  // -------------------- Helpers --------------------

  String _safeStr(dynamic v) => (v == null) ? "" : v.toString();

  String _formatDate(dynamic raw) {
    final s = _safeStr(raw);
    if (s.isEmpty) return "";
    try {
      // supports "2026-02-16", "2026-02-16 10:20:00", ISO, etc.
      final dt = DateTime.parse(s.replaceAll(' ', 'T'));
      return DateFormat("dd-MM-yyyy, hh:mm a").format(dt);
    } catch (_) {
      return s; // fallback: show as-is
    }
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

      double progress = 0;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text("Downloading..."),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress == 0 ? null : progress),
                const SizedBox(height: 12),
                Text(
                  progress == 0
                      ? "Starting..."
                      : "${(progress * 100).toStringAsFixed(0)}%",
                ),
              ],
            ),
          ),
        ),
      );

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progress = received / total;

            if (mounted) {
              // ✅ simple refresh: close & reopen dialog
              Navigator.of(context).maybePop();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: const Text("Downloading..."),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 12),
                      Text("${(progress * 100).toStringAsFixed(0)}%"),
                    ],
                  ),
                ),
              );
            }
          }
        },
      );

      if (mounted) Navigator.of(context).maybePop(); // close dialog

      _toast("Downloaded: $name");
      await OpenFilex.open(savePath);
    } catch (e) {
      if (mounted) Navigator.of(context).maybePop();
      _toast("Download failed");
      debugPrint("Download error: $e");
    }
  }

  /// ✅ FIXED: attachments can be List / String / Map / comma-separated string
  List<Map<String, String>> _parseAttachments(Map<String, dynamic> n) {
    final rawAtt =
        n['attachments'] ??
        n['files'] ??
        n['attachment'] ??
        n['file'] ??
        n['file_url'] ??
        n['notice_file'];

    final List<Map<String, String>> attachments = [];

    void addAttachment(dynamic a) {
      if (a == null) return;

      // ✅ single string url
      if (a is String) {
        final url = _safeStr(a).trim();
        if (url.isEmpty) return;

        // ✅ comma-separated urls handle
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

      // ✅ map object
      if (a is Map) {
        final url = _safeStr(
          a['url'] ?? a['file'] ?? a['path'] ?? a['file_url'],
        ).trim();
        if (url.isEmpty) return;
        final name = _safeStr(a['name'] ?? a['file_name'] ?? a['title']).trim();
        attachments.add({
          "url": url,
          "name": name.isNotEmpty ? name : url.split('/').last.split('?').first,
        });
        return;
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

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.primary,
        // ✅ your primary
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
            : (notices.isEmpty ? _emptyState() : _noticeList()),
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
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              color: Colors.black.withOpacity(0.06),
              offset: const Offset(0, 8),
            ),
          ],
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
        final date = _formatDate(
          n['date'] ?? n['created_at'] ?? n['publish_date'],
        );

        final attachments = _parseAttachments(n);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
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
              // title + date
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary, // ✅ your primary
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.bell_fill,
                      color: Colors.white,
                      size: 22,
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
                        if (date.isNotEmpty)
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
                                  date,
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
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.72),
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        );
      },
    );
  }

  Widget _attachmentTile(String url, String name) {
    final isImg = _isImageUrl(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        // color: const Color(0xFFF7F8FD),
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
                color: Color(0xFFF7F8FD),
                borderRadius: BorderRadius.all(Radius.circular(14))
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
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 12,
                          color: Colors.black.withOpacity(0.06),
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      isImg ? CupertinoIcons.photo_fill : _fileIcon(url),
                      color: AppColors.primary, // ✅ your primary
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _miniBtn(
                    icon: CupertinoIcons.eye,
                    label: "Open",
                    onTap: () => _openUrl(url),
                  ),
                  const SizedBox(width: 8),
                  _miniBtn(
                    icon: CupertinoIcons.arrow_down_to_line,
                    label: "Download",
                    onTap: () => _downloadFile(url: url, fileName: name),
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
          color: AppColors.primary, // ✅ your primary
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
