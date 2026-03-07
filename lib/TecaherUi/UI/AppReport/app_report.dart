import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _parseLastActive(dynamic raw) {
  if (raw == null || raw.toString().trim().isEmpty) return 'Not active';
  try {
    final dt = DateTime.parse(raw.toString().trim());
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  } catch (_) {
    return raw.toString();
  }
}

Color _activeColor(String lastActive) {
  if (lastActive.contains('min') || lastActive.contains('now')) {
    return const Color(0xFF00C853);
  } else if (lastActive.contains('hr')) {
    return const Color(0xFFFF9100);
  }
  return const Color(0xFFBDBDBD);
}

// ─── Models ───────────────────────────────────────────────────────────────────

class StaffModel {
  final String teacherName;
  final String designation;
  final String lastActive;
  final String avatarInitials;
  final Color avatarColor;

  const StaffModel({
    required this.teacherName,
    required this.designation,
    required this.lastActive,
    required this.avatarInitials,
    required this.avatarColor,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    final name =
        (json['first_name'] ?? json['teacher_name'] ?? json['name'] ?? '')
            as String;
    final trimmed = name.trim();
    final initials = trimmed.isNotEmpty
        ? trimmed
              .split(' ')
              .where((e) => e.isNotEmpty)
              .take(2)
              .map((e) => e[0])
              .join()
              .toUpperCase()
        : '?';

    final colors = [
      const Color(0xFF5C6BC0),
      const Color(0xFFEC407A),
      const Color(0xFF26A69A),
      const Color(0xFFFF7043),
      const Color(0xFF8D6E63),
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
      const Color(0xFF66BB6A),
    ];
    final color = colors[trimmed.isEmpty ? 0 : trimmed.length % colors.length];

    return StaffModel(
      teacherName: trimmed,
      designation: (json['designation'] ?? '').toString().trim(),
      lastActive: _parseLastActive(json['app_last_active']),
      avatarInitials: initials,
      avatarColor: color,
    );
  }
}

class StudentModel {
  final String name;
  final String classSection;
  final String admNo;
  final String rollNumber;
  final String lastActive;
  final Color avatarColor;

  const StudentModel({
    required this.name,
    required this.classSection,
    required this.admNo,
    required this.rollNumber,
    required this.lastActive,
    required this.avatarColor,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    final name = (json['student_name'] ?? '').toString().trim();
    final colors = [
      const Color(0xFF5C6BC0),
      const Color(0xFFEC407A),
      const Color(0xFF26A69A),
      const Color(0xFFFF7043),
      const Color(0xFFAB47BC),
      const Color(0xFF42A5F5),
      const Color(0xFF66BB6A),
      const Color(0xFF8D6E63),
    ];
    final color = colors[name.isEmpty ? 0 : name.length % colors.length];

    return StudentModel(
      name: name,
      classSection: (json['class_section'] ?? '').toString(),
      admNo: json['adm_no']?.toString() ?? '',
      rollNumber: json['roll_no']?.toString() ?? '-',
      lastActive: _parseLastActive(json['app_last_active']),
      avatarColor: color,
    );
  }
}

// ─── API Service ───────────────────────────────────────────────────────────────

class AppReportService {

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('teachertoken');
  }

  static Future<Map<String, dynamic>> fetchStaff() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse(ApiRoutes.getTeacherAppReport),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load staff: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> fetchStudents({int page = 1}) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${ApiRoutes.getStudentAppReport}$page'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load students: ${response.statusCode}');
  }
}

// ─── Count Banner ──────────────────────────────────────────────────────────────

class _CountBanner extends StatelessWidget {
  final int total;
  final int active;
  final bool isStaff;

  const _CountBanner({
    required this.total,
    required this.active,
    required this.isStaff,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = total - active;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isStaff
              ? [const Color(0xFFB71C1C), const Color(0xFFE53935)]
              : [const Color(0xFFB71C1C), const Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (isStaff ? const Color(0xFFB71C1C) : const Color(0xFFB71C1C))
                .withOpacity(0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isStaff ? Icons.badge_rounded : Icons.school_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          // Count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStaff ? 'Total Staff' : 'Total Students',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          // Pills
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _pill(const Color(0xFF00E676), '$active Active'),
              const SizedBox(height: 7),
              _pill(Colors.white.withOpacity(0.55), '$inactive Inactive'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(Color dotColor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Main Screen ───────────────────────────────────────────────────────────────

class AppReportScreen extends StatefulWidget {
  const AppReportScreen({super.key});

  @override
  State<AppReportScreen> createState() => _AppReportScreenState();
}

class _AppReportScreenState extends State<AppReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // IconButton(
              //   icon: const Icon(Icons.download_rounded, color: Colors.white),
              //   onPressed: () {},
              // ),
            ],
            title: const Text(
              'App Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: _buildTabBar(),
            ),
          ),
        ],
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _StaffTab(searchQuery: _searchQuery),
                  _StudentTab(searchQuery: _searchQuery),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.badge_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Staff'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Students'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: _tabController.index == 0
                    ? 'Search staff by name or designation...'
                    : 'Search student by name, adm no...',
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFFB71C1C),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Download Button
          InkWell(
            onTap: () {
              if (_tabController.index == 0) {
                _downloadStaffReport();
              } else {
                _downloadStudentReport();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.download_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _openInBrowser(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // Device ka default browser open hoga
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $url')),
      );
    }
  }
  void _downloadStaffReport() {
    _openInBrowser('https://softcjm.cjmambala.co.in/app-report-teacher');
  }

  void _downloadStudentReport() {
    _openInBrowser('https://softcjm.cjmambala.co.in/app-report-student');
  }
}

// ─── Staff Tab ─────────────────────────────────────────────────────────────────

class _StaffTab extends StatefulWidget {
  final String searchQuery;

  const _StaffTab({required this.searchQuery});

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab>
    with AutomaticKeepAliveClientMixin {
  List<StaffModel> _allStaff = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await AppReportService.fetchStaff();
      final staffData = data['data']?['users'] ?? [];
      final list = (staffData as List)
          .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _allStaff = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) return _buildError(_error!);

    final filtered = _allStaff
        .where(
          (s) =>
              s.teacherName.toLowerCase().contains(widget.searchQuery) ||
              s.designation.toLowerCase().contains(widget.searchQuery),
        )
        .toList();

    final activeCount = _allStaff
        .where((s) => s.lastActive != 'Not active')
        .length;

    return RefreshIndicator(
      onRefresh: _loadStaff,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: filtered.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CountBanner(
              total: _allStaff.length,
              active: activeCount,
              isStaff: true,
            );
          }
          return _StaffCard(staff: filtered[index - 1]);
        },
      ),
    );
  }

  Widget _buildError(String error) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(
          'Something went wrong',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadStaff,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Staff Card ────────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final StaffModel staff;

  const _StaffCard({required this.staff});

  @override
  Widget build(BuildContext context) {
    final isActive = staff.lastActive != 'Not active';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        staff.avatarColor,
                        staff.avatarColor.withOpacity(0.72),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      staff.avatarInitials,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + designation badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.teacherName,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: staff.avatarColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          staff.designation,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: staff.avatarColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Active status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _activeColor(staff.lastActive),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            color: _activeColor(staff.lastActive),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      staff.lastActive,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Student Tab ───────────────────────────────────────────────────────────────

class _StudentTab extends StatefulWidget {
  final String searchQuery;

  const _StudentTab({required this.searchQuery});

  @override
  State<_StudentTab> createState() => _StudentTabState();
}

class _StudentTabState extends State<_StudentTab>
    with AutomaticKeepAliveClientMixin {
  final List<StudentModel> _allStudents = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadStudents(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _currentPage <= _lastPage) {
      _loadStudents();
    }
  }

  Future<void> _loadStudents({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _allStudents.clear();
        _currentPage = 1;
      });
    } else {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final data = await AppReportService.fetchStudents(page: _currentPage);
      final pagination = data['data']['students'] as Map<String, dynamic>;
      final list = (pagination['data'] as List)
          .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _allStudents.addAll(list);
          _lastPage = pagination['last_page'] as int;
          _totalCount = pagination['total'] as int? ?? _allStudents.length;
          _currentPage++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null && _allStudents.isEmpty) return _buildError(_error!);

    final filtered = _allStudents
        .where(
          (s) =>
              s.name.toLowerCase().contains(widget.searchQuery) ||
              s.admNo.toLowerCase().contains(widget.searchQuery) ||
              s.classSection.toLowerCase().contains(widget.searchQuery),
        )
        .toList();

    if (filtered.isEmpty && widget.searchQuery.isNotEmpty) {
      return _buildEmpty('No students found');
    }

    final activeCount = _allStudents
        .where((s) => s.lastActive != 'Not active')
        .length;

    return RefreshIndicator(
      onRefresh: () => _loadStudents(reset: true),
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: filtered.length + 1 + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CountBanner(
              total: _totalCount,
              active: activeCount,
              isStaff: false,
            );
          }
          final i = index - 1;
          if (i == filtered.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return _StudentCard(student: filtered[i], index: i);
        },
      ),
    );
  }

  Widget _buildEmpty(String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(msg, style: TextStyle(color: Colors.grey[400], fontSize: 15)),
      ],
    ),
  );

  Widget _buildError(String error) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wifi_off_rounded, size: 60, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(
          'Something went wrong',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _loadStudents(reset: true),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Student Card ──────────────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final int index;

  const _StudentCard({required this.student, required this.index});

  String get _initials {
    final trimmed = student.name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0])
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = student.lastActive != 'Not active';
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () {},
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            student.avatarColor,
                            student.avatarColor.withOpacity(0.70),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: Text(
                          _initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 0),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: student.avatarColor.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  student.classSection,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: student.avatarColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(width: 5.sp),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: student.avatarColor.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ' Adm No: ${student.admNo.isNotEmpty ? student.admNo : '-'}',
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              SizedBox(width: 5.sp),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: student.avatarColor.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ' Roll No: ${student.rollNumber}',
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),

                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _activeColor(student.lastActive),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                color: _activeColor(student.lastActive),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          student.lastActive,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
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

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
