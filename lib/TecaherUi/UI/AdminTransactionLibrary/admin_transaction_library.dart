import 'dart:convert';

import 'package:avi/constants.dart';
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

  static String formatDate(dynamic value) {
    final dt = _parseDate(value);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;

    try {
      return DateTime.parse(raw);
    } catch (_) {}

    try {
      if (raw.contains('-') && raw.length == 10) {
        final parts = raw.split('-');
        if (parts.first.length == 4) {
          return DateFormat('yyyy-MM-dd').parseStrict(raw);
        } else {
          return DateFormat('dd-MM-yyyy').parseStrict(raw);
        }
      }
    } catch (_) {}

    try {
      if (raw.contains('/')) return DateFormat('dd/MM/yyyy').parseLoose(raw);
    } catch (_) {}

    return null;
  }

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

  // ✅ Type badge color: Teacher = blue, Student = purple
  static Color typeColor(dynamic type) {
    final t = _norm(type);
    if (t == 'teacher') return Colors.blue;
    if (t == 'student') return Colors.deepPurple;
    return Colors.grey;
  }

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
/// ✅ MODEL: issued_books item (with new fields)
/// =======================================================
class IssuedBookModel {
  final String name;       // NEW: "NAVEEN RATURI"
  final String type;       // NEW: "Teacher" | "Student"
  final String admNo;      // NEW: admission no (or "-" for teachers)
  final String className;  // NEW: class (or "-" for teachers)
  final String bookName;
  final int accessionNo;
  final String issueDate;
  final String dueDate;
  final String returnDate;
  final String status;

  IssuedBookModel({
    required this.name,
    required this.type,
    required this.admNo,
    required this.className,
    required this.bookName,
    required this.accessionNo,
    required this.issueDate,
    required this.dueDate,
    required this.returnDate,
    required this.status,
  });

  factory IssuedBookModel.fromJson(Map<String, dynamic> json) {
    return IssuedBookModel(
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      admNo: (json['adm_no'] ?? '-').toString(),
      className: (json['class'] ?? '-').toString(),
      bookName: (json['book_name'] ?? '').toString(),
      accessionNo: _toInt(json['accession_no']),
      issueDate: (json['issue_date'] ?? '').toString(),
      dueDate: (json['due_date'] ?? '').toString(),
      returnDate: (json['return_date'] ?? '').toString(),
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
/// =======================================================
class AdminBooksScreen extends StatefulWidget {
  const AdminBooksScreen({super.key});

  @override
  State<AdminBooksScreen> createState() => _IssuedBooksScreenState();
}

class _IssuedBooksScreenState extends State<AdminBooksScreen> {
  bool isLoading = false;
  List<IssuedBookModel> list = [];

  // ✅ Search + Filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'All';   // All | Teacher | Student
  String _selectedStatus = 'All'; // All | Issued | Returned | Delayed

  static const _typeOptions = ['All', 'Teacher', 'Student'];
  static const _statusOptions = ['All', 'Issued', 'Returned', 'Delayed'];

  List<IssuedBookModel> get _filtered {
    return list.where((b) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          b.name.toLowerCase().contains(q) ||
          b.bookName.toLowerCase().contains(q) ||
          b.admNo.toLowerCase().contains(q) ||
          b.accessionNo.toString().contains(q);

      final matchType = _selectedType == 'All' ||
          b.type.toLowerCase() == _selectedType.toLowerCase();

      final matchStatus = _selectedStatus == 'All' ||
          IssuedBooksLibrary.statusText(b.status) == _selectedStatus;

      return matchSearch && matchType && matchStatus;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    fetchIssuedBooks();
  }

  Future<void> fetchIssuedBooks() async {
    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final teacherToken = prefs.getString('teachertoken');

    final url = Uri.parse(ApiRoutes.getBooksAdmin);

    try {
      final res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $teacherToken',
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
          "Library Issued Books",
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
          : Column(
        children: [
          // ✅ Search bar
          Container(
            color: AppColors.primary,
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: TextStyle(fontSize: 13.sp, color: Colors.black),
              decoration: InputDecoration(
                hintText: "Search by name, book, accession no...",
                hintStyle: TextStyle(fontSize: 13.sp, color: Colors.black45),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.black45),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black45),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 4.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ✅ Type filter chips row
          _FilterRow(
            label: "Type",
            options: _typeOptions,
            selected: _selectedType,
            onSelect: (v) => setState(() => _selectedType = v),
            colorOf: (v) {
              if (v == 'Teacher') return Colors.blue;
              if (v == 'Student') return Colors.deepPurple;
              return AppColors.primary;
            },
          ),

          // ✅ Status filter chips row
          _FilterRow(
            label: "Status",
            options: _statusOptions,
            selected: _selectedStatus,
            onSelect: (v) => setState(() => _selectedStatus = v),
            colorOf: (v) => IssuedBooksLibrary.statusColor(v),
          ),

          // ✅ Result count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            child: Row(
              children: [
                Text(
                  "${_filtered.length} record${_filtered.length == 1 ? '' : 's'}",
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),

          // ✅ List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
              child: Text(
                "No records found",
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final b = _filtered[i];
                return IssuedBookTile(
                  data: b,
                  onTap: () => _showDetails(b),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(IssuedBookModel b) {
    final statusColor = IssuedBooksLibrary.statusColor(b.status);
    final typeColor = IssuedBooksLibrary.typeColor(b.type);
    final isStudent = b.type.toLowerCase() == 'student';

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
              // Drag handle
              Container(
                height: 4.h,
                width: 54.w,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(20.r),
                ),
              ),
              SizedBox(height: 14.h),

              // Header: icon + book name
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

              // ✅ Person info section
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(.07),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: typeColor.withOpacity(.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18.r,
                      backgroundColor: typeColor.withOpacity(.15),
                      child: Icon(
                        isStudent
                            ? Icons.school_rounded
                            : Icons.person_rounded,
                        color: typeColor,
                        size: 18.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              // Type badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  b.type,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              if (isStudent) ...[
                                SizedBox(width: 6.w),
                                Text(
                                  "${b.className}  •  Adm: ${b.admNo}",
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),

              // Book details rows
              _row("Status", IssuedBooksLibrary.statusText(b.status)),
              _row("Accession No.", b.accessionNo.toString()),
              _row("Issue Date", IssuedBooksLibrary.formatDate(b.issueDate)),
              _row("Due Date", IssuedBooksLibrary.formatDate(b.dueDate)),
              _row(
                "Return Date",
                b.returnDate.trim().isEmpty ||
                    b.returnDate.toLowerCase() == 'null'
                    ? "-"
                    : IssuedBooksLibrary.formatDate(b.returnDate),
              ),
              SizedBox(height: 16.h),

              // Close button
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
/// ✅ FILTER ROW — horizontal chip row
/// =======================================================
class _FilterRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final Color Function(String) colorOf;

  const _FilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      child: Row(
        children: [
          Text(
            "$label:",
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w800,
              color: Colors.black45,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: options.map((opt) {
                  final isActive = selected == opt;
                  final color = opt == 'All' ? Colors.black54 : colorOf(opt);
                  return GestureDetector(
                    onTap: () => onSelect(opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: 8.w),
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: isActive ? color : color.withOpacity(.09),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isActive ? color : color.withOpacity(.25),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: isActive ? Colors.white : color,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final typeColor = IssuedBooksLibrary.typeColor(data.type);
    final returned = IssuedBooksLibrary.isReturned(data.status);
    final isStudent = data.type.toLowerCase() == 'student';

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
              // Book icon
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

              // Center info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.bookName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),

                    // ✅ Person name
                    Text(
                      data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // ✅ Type badge + class/admno
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 7.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            data.type,
                            style: TextStyle(
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w800,
                              color: typeColor,
                            ),
                          ),
                        ),
                        if (isStudent) ...[
                          SizedBox(width: 5.w),
                          Flexible(
                            child: Text(
                              "${data.className}  •  ${data.admNo}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4.h),

                    // Book name
                    Text(
                      'Acc. No : ${data.accessionNo.toString()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // Due / Returned date
                    Text(
                      returned
                          ? "Returned: ${IssuedBooksLibrary.formatDate(data.returnDate)}"
                          : "Due: ${IssuedBooksLibrary.formatDate(data.dueDate)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: returned ? Colors.green : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 10.w),

              // Status badge
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