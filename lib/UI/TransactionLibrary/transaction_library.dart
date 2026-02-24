import 'dart:convert';

import 'package:avi/constants.dart'; // ✅ AppColors.primary, ApiRoutes (agar ho)
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// =======================================================
/// ✅ ISSUED BOOKS LIBRARY (Date + Status helpers)
/// =======================================================
class IssuedBooksLibrary {
  IssuedBooksLibrary._();

  // ---------------------------
  // ✅ DATE / TIME
  // ---------------------------
  static String formatDate(dynamic value) {
    final dt = _parseDate(value);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;

    // try ISO
    try {
      return DateTime.parse(raw);
    } catch (_) {}

    // common formats
    try {
      // API: "05-02-2026"
      if (raw.contains('-') && raw.length == 10) {
        // could be dd-MM-yyyy or yyyy-MM-dd
        final parts = raw.split('-');
        if (parts.first.length == 4) {
          return DateFormat('yyyy-MM-dd').parseStrict(raw);
        } else {
          return DateFormat('dd-MM-yyyy').parseStrict(raw);
        }
      }
    } catch (_) {}

    try {
      // "05/02/2026"
      if (raw.contains('/')) return DateFormat('dd/MM/yyyy').parseLoose(raw);
    } catch (_) {}

    return null;
  }

  // ---------------------------
  // ✅ STATUS
  // ---------------------------
  static String statusText(dynamic status) {
    final s = _norm(status);
    if (s == 'delayed' || s == 'late' || s == 'overdue') return 'Delayed';
    if (s == 'returned' || s == 'return') return 'Returned';
    if (s == 'issued' || s == 'active' || s == 'pending') return 'Issued';
    return s.isEmpty ? '' : _capWords(s);
  }

  static bool isReturned(dynamic status) => _norm(status) == 'returned';

  static Color statusColor(dynamic status) {
    final s = _norm(status);
    if (s == 'returned') return Colors.green;
    if (s == 'delayed' || s == 'overdue' || s == 'late') return Colors.red;
    if (s == 'issued' || s == 'active' || s == 'pending') return Colors.orange;
    return Colors.grey;
  }

  static IconData statusIcon(dynamic status) {
    final s = _norm(status);
    if (s == 'returned') return Icons.check_circle_rounded;
    if (s == 'delayed' || s == 'overdue' || s == 'late') {
      return Icons.warning_amber_rounded;
    }
    if (s == 'issued' || s == 'active' || s == 'pending') {
      return Icons.bookmark_added_rounded;
    }
    return Icons.info_rounded;
  }

  // ---------------------------
  // ✅ UTIL
  // ---------------------------
  static String maskAcc(dynamic no, {int showStart = 3, int showEnd = 2}) {
    if (no == null) return '';
    final s = no.toString().trim();
    if (s.length <= (showStart + showEnd)) return s;
    return '${s.substring(0, showStart)}${'•' * 5}${s.substring(s.length - showEnd)}';
  }

  static String _norm(dynamic v) => (v ?? '').toString().trim().toLowerCase();

  static String _capWords(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}

/// =======================================================
/// ✅ MODEL: issued_books item
/// =======================================================
class IssuedBookModel {
  final String bookName;
  final int accessionNo;
  final String issueDate;
  final String dueDate;
  final String returnDate;
  final String status;

  IssuedBookModel({
    required this.bookName,
    required this.accessionNo,
    required this.issueDate,
    required this.dueDate,
    required this.returnDate,
    required this.status,
  });

  factory IssuedBookModel.fromJson(Map<String, dynamic> json) {
    return IssuedBookModel(
      bookName: (json['book_name'] ?? '').toString(),
      accessionNo: _toInt(json['accession_no']),
      issueDate: (json['issue_date'] ?? '').toString(),
      dueDate: (json['due_date'] ?? '').toString(),
      returnDate: (json['return_date'] ?? '').toString(), // can be null
      status: (json['status'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}

/// =======================================================
/// ✅ SCREEN: Issued Books
/// API: http://192.168.1.9/cjm_ambala12/api/issued-books
/// TOKEN: token OR teachertoken (multi teacher)
/// =======================================================
class IssuedBooksScreen extends StatefulWidget {
  const IssuedBooksScreen({super.key});

  @override
  State<IssuedBooksScreen> createState() => _IssuedBooksScreenState();
}

class _IssuedBooksScreenState extends State<IssuedBooksScreen> {
  bool isLoading = false;
  List<IssuedBookModel> list = [];

  @override
  void initState() {
    super.initState();
    fetchIssuedBooks();
  }

  Future<void> fetchIssuedBooks() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    // ✅ MULTI TOKEN SUPPORT (student token + teacher token)
    final token = prefs.getString('token');
    final teacherToken = prefs.getString('teachertoken');

    // priority: token -> teachertoken
    final useToken = (token != null && token.trim().isNotEmpty)
        ? token
        : (teacherToken ?? '');

    if (useToken.trim().isEmpty) {
      setState(() => isLoading = false);
      _snack("Token missing. Login again.");
      return;
    }

    final url =
    Uri.parse(ApiRoutes.getIssuedBooks);

    try {
      final res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $useToken',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (data['issued_books'] ?? []) as List;

        setState(() {
          list = items
              .map((e) => IssuedBookModel.fromJson(e as Map<String, dynamic>))
              .toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        _snack("Server error: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _snack("Error fetching issued books");
      debugPrint("IssuedBooks API error: $e");
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Issued Books",
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: fetchIssuedBooks,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
          ? Center(
        child: Text(
          "No issued books found",
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      )
          : ListView.builder(
        padding: EdgeInsets.all(10.sp),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final b = list[i];
          return IssuedBookTile(
            data: b,
            onTap: () => _showDetails(b),
          );
        },
      ),
    );
  }

  void _showDetails(IssuedBookModel b) {
    final statusColor = IssuedBooksLibrary.statusColor(b.status);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 12.h,
            bottom: 16.h + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4.h,
                width: 54.w,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: statusColor.withOpacity(.12),
                    child: Icon(
                      IssuedBooksLibrary.statusIcon(b.status),
                      color: statusColor,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      b.bookName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              _row("Status", IssuedBooksLibrary.statusText(b.status)),
              _row("Accession No.", b.accessionNo.toString()),
              _row("Issue Date", IssuedBooksLibrary.formatDate(b.issueDate)),
              _row("Due Date", IssuedBooksLibrary.formatDate(b.dueDate)),
              _row(
                "Return Date",
                b.returnDate.toString().trim().isEmpty ||
                    b.returnDate.toString().toLowerCase() == 'null'
                    ? "-"
                    : IssuedBooksLibrary.formatDate(b.returnDate),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text("Close"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String left, String right) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              right.isEmpty ? "-" : right,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// ✅ TILE (Premium look)
/// =======================================================
class IssuedBookTile extends StatelessWidget {
  final IssuedBookModel data;
  final VoidCallback onTap;

  const IssuedBookTile({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = IssuedBooksLibrary.statusColor(data.status);
    final returned = IssuedBooksLibrary.isReturned(data.status);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          width: 1,
          color: statusColor.withOpacity(.35),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.all(12.sp),
          child: Row(
            children: [
              Container(
                height: 48.h,
                width: 48.h,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: statusColor,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.bookName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      "Acc: ${IssuedBooksLibrary.maskAcc(data.accessionNo)}",
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      returned
                          ? "Returned: ${IssuedBooksLibrary.formatDate(data.returnDate)}"
                          : "Due: ${IssuedBooksLibrary.formatDate(data.dueDate)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: returned ? Colors.green : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 10.w),

              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      IssuedBooksLibrary.statusIcon(data.status),
                      size: 16.sp,
                      color: statusColor,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      IssuedBooksLibrary.statusText(data.status),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
