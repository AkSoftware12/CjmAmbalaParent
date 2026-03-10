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
  if (lastActive == 'Not active') return const Color(0xFFBDBDBD);
  return const Color(0xFF00C853);
}

// ─── Models ───────────────────────────────────────────────────────────────────

class ClassModel {
  final int id;
  final String name;
  const ClassModel({required this.id, required this.name});

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as int,
      name: (json['class'] ?? '').toString(),
    );
  }
}

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

  /// [status] → 'all' | 'active' | 'inactive'
  static Future<Map<String, dynamic>> fetchStaff({
    String status = 'all',
  }) async {
    final token = await _getToken();

    final params = <String, String>{};
    if (status != 'all') params['status'] = status;

    final uri = Uri.parse(ApiRoutes.getTeacherAppReport).replace(
      queryParameters: params.isNotEmpty ? params : null,
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load staff: ${response.statusCode}');
  }

  /// [status] → 'all' | 'active' | 'inactive'
  /// [classId] → null means all classes
  static Future<Map<String, dynamic>> fetchStudents({
    int page = 1,
    String status = 'all',
    int? classId,
  }) async {
    final token = await _getToken();

    final params = <String, String>{'page': '$page'};
    if (status != 'all') params['status'] = status;
    if (classId != null) params['class'] = '$classId';

    final uri = Uri.parse(ApiRoutes.getStudentAppReport).replace(
      queryParameters: params,
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
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
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB71C1C).withOpacity(0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
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

  // Both URLs are now dynamic (updated via callbacks from child tabs)
  String _staffDownloadUrl =
      'https://softcjm.cjmambala.co.in/app-report-teacher';
  String _studentDownloadUrl =
      'https://softcjm.cjmambala.co.in/app-report-student';

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
                  _StaffTab(
                    searchQuery: _searchQuery,
                    onUrlChanged: (url) {
                      if (url.isNotEmpty) {
                        setState(() => _staffDownloadUrl = url);
                      }
                    },
                  ),
                  _StudentTab(
                    searchQuery: _searchQuery,
                    onUrlChanged: (url) =>
                        setState(() => _studentDownloadUrl = url),
                  ),
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
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: _tabController.index == 0
                    ? 'Search staff by name or designation...'
                    : 'Search student by name, adm no...',
                hintStyle: const TextStyle(
                  color: Color(0xFFBBBBBB),
                  fontSize: 13,
                ),
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $url')),
      );
    }
  }

  void _downloadStaffReport() {
    _openInBrowser(_staffDownloadUrl);
  }

  void _downloadStudentReport() {
    _openInBrowser(_studentDownloadUrl);
  }
}

// ─── Staff Tab ─────────────────────────────────────────────────────────────────

class _StaffTab extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String>? onUrlChanged;

  const _StaffTab({required this.searchQuery, this.onUrlChanged});

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab>
    with AutomaticKeepAliveClientMixin {
  List<StaffModel> _allStaff = [];
  bool _isLoading = true;
  String? _error;

  // Filter + counts + url
  String _selectedStatus = 'all';
  int _totalCount = 0;
  int _activeCount = 0;
  String _downloadUrl = '';

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
      final data = await AppReportService.fetchStaff(status: _selectedStatus);

      final staffData = data['data']?['users'] ?? [];
      final list = (staffData as List)
          .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _allStaff = list;
          _totalCount = (data['total'] as int?) ?? list.length;
          _activeCount = (data['active'] as int?) ?? 0;
          _downloadUrl = (data['url'] as String?) ?? '';
          _isLoading = false;
        });
        widget.onUrlChanged?.call(_downloadUrl);
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

  void _applyFilters() => _loadStaff();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) return _buildError(_error!);

    final filtered = _allStaff
        .where(
          (s) =>
      s.teacherName.toLowerCase().contains(widget.searchQuery) ||
          s.designation.toLowerCase().contains(widget.searchQuery),
    )
        .toList();

    // API se active count nahi aaya toh locally count karo
    final activeCount = _activeCount > 0
        ? _activeCount
        : _allStaff.where((s) => s.lastActive != 'Not active').length;

    return RefreshIndicator(
      onRefresh: _loadStaff,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: filtered.isEmpty
            ? 3 // banner + filter + empty
            : filtered.length + 2, // banner + filter + cards
        itemBuilder: (context, index) {
          // index 0 → Count Banner
          if (index == 0) {
            return _CountBanner(
              total: _totalCount > 0 ? _totalCount : _allStaff.length,
              active: activeCount,
              isStaff: true,
            );
          }

          // index 1 → Filter Row
          if (index == 1) {
            return _buildFilterRow();
          }

          final i = index - 2;

          // Empty state
          if (filtered.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      'No staff found',
                      style:
                      TextStyle(color: Colors.grey[400], fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          }

          return _StaffCard(staff: filtered[i]);
        },
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: _FilterDropdown<String>(
        icon: Icons.filter_list_rounded,
        value: _selectedStatus,
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Status')),
          DropdownMenuItem(value: 'active', child: Text('Active')),
          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
        ],
        onChanged: (val) {
          if (val == null) return;
          setState(() => _selectedStatus = val);
          _applyFilters();
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

// ─── Student Tab (with Status + Class Filters) ─────────────────────────────────

class _StudentTab extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String>? onUrlChanged;
  const _StudentTab({required this.searchQuery, this.onUrlChanged});

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
  int _activeCount = 0;
  String _downloadUrl = '';

  // ── Filter state ──
  List<ClassModel> _classes = [];
  int? _selectedClassId;
  String _selectedStatus = 'all';

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
        _activeCount = 0;
      });
    } else {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final data = await AppReportService.fetchStudents(
        page: _currentPage,
        status: _selectedStatus,
        classId: _selectedClassId,
      );

      if (_classes.isEmpty && data['classes'] != null) {
        final classList = data['classes'] as List;
        _classes = classList
            .map((e) => ClassModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final pagination = data['data']['students'] as Map<String, dynamic>;
      final list = (pagination['data'] as List)
          .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _allStudents.addAll(list);
          _lastPage = pagination['last_page'] as int;
          _totalCount = pagination['total'] as int? ?? _allStudents.length;
          if (reset || _currentPage == 1) {
            _activeCount = (data['active'] as int?) ?? 0;
            _downloadUrl = (data['url'] as String?) ?? '';
            widget.onUrlChanged?.call(_downloadUrl);
          }
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

  void _applyFilters() {
    _loadStudents(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
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

    return RefreshIndicator(
      onRefresh: () => _loadStudents(reset: true),
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: filtered.length + 2 + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CountBanner(
              total: _totalCount,
              active: _activeCount,
              isStaff: false,
            );
          }

          if (index == 1) {
            return _buildFilterRow();
          }

          final i = index - 2;

          if (i == filtered.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (filtered.isEmpty && widget.searchQuery.isNotEmpty) {
            return _buildEmpty('No students found');
          }

          return _StudentCard(student: filtered[i], index: i);
        },
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: _FilterDropdown<String>(
              icon: Icons.filter_list_rounded,
              value: _selectedStatus,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Status')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() => _selectedStatus = val);
                _applyFilters();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterDropdown<int?>(
              icon: Icons.class_rounded,
              value: _selectedClassId,
              hint: 'All Classes',
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Classes'),
                ),
                ..._classes.map(
                      (c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(c.name),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedClassId = val);
                _applyFilters();
              },
            ),
          ),
        ],
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

// ─── Generic Filter Dropdown ───────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String? hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint ?? '',
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFFB71C1C),
          ),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _badge(student.classSection, student.avatarColor),
                          SizedBox(width: 4.sp),
                          _badge(
                            'Adm: ${student.admNo.isNotEmpty ? student.admNo : '-'}',
                            Colors.grey,
                            textColor: Colors.grey[700]!,
                          ),
                          SizedBox(width: 4.sp),
                          _badge(
                            'Roll: ${student.rollNumber}',
                            Colors.grey,
                            textColor: Colors.grey[700]!,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
        ),
      ),
    );
  }

  Widget _badge(String label, Color bgColor, {Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: textColor ?? bgColor,
        ),
      ),
    );
  }
}