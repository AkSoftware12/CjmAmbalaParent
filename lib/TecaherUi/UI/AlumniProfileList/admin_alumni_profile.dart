import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../constants.dart';

// ==================== MODEL ====================

class AdminAlumniProfile {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String dob;
  final String yearOfPassing;
  final String classPassed;
  final String section;
  final String house;
  final String favouriteSubject;
  final String favouriteTeacher;
  final String occupation;
  final String organisation;
  final String city;
  final String? photoUrl;

  AdminAlumniProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.dob,
    required this.yearOfPassing,
    required this.classPassed,
    required this.section,
    required this.house,
    required this.favouriteSubject,
    required this.favouriteTeacher,
    required this.occupation,
    required this.organisation,
    required this.city,
    this.photoUrl,
  });

  factory AdminAlumniProfile.fromJson(Map<String, dynamic> json) {
    // Nested objects (profile / details / user etc.) ko bhi flatten kar lo
    final flat = <String, dynamic>{};
    json.forEach((k, v) {
      if (v is! Map<String, dynamic>) flat[k.toString()] = v;
    });
    void merge(Map<String, dynamic> m) {
      m.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          merge(v);
        } else {
          flat.putIfAbsent(k.toString(), () => v);
        }
      });
    }

    merge(json);

    String pick(List<String> keys) {
      for (final k in keys) {
        final v = flat[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    // API "photo_url" mein full URL bhejti hai (jab photo ho),
    // "photo" mein sirf filename hota hai — usko use NAHI karna (crash hota tha)
    final photo = pick(['photo_url', 'profile_photo_url', 'image_url']);

    return AdminAlumniProfile(
      id: int.tryParse(pick(['id', 'alumni_id', 'user_id'])) ?? 0,
      fullName: pick(['full_name', 'name', 'fullname']),
      email: pick(['email', 'email_id']),
      phone: pick(['phone', 'mobile', 'phone_number', 'contact']),
      address: pick(['address', 'full_address']),
      dob: pick(['dob', 'date_of_birth', 'birth_date', 'birthdate']),
      yearOfPassing: pick([
        'year_of_passing',
        'passing_year',
        'passout_year',
        'batch',
        'batch_year',
      ]),
      classPassed: pick([
        'class_passed',
        'class',
        'class_name',
        'last_class',
        'passed_class',
      ]),
      section: pick(['section', 'section_name']),
      house: pick(['house', 'house_name']),
      favouriteSubject: pick(['favourite_subject', 'favorite_subject']),
      favouriteTeacher: pick(['favourite_teacher', 'favorite_teacher']),
      occupation: pick(['occupation', 'profession', 'job']),
      organisation: pick(['organisation', 'organization', 'company']),
      city: pick(['city', 'current_city']),
      photoUrl: photo.isEmpty ? null : photo,
    );
  }

  /// Sirf valid absolute URL hi use karo — relative filename
  /// ("1784353219_alumni007.jpg") pe NetworkImage crash karta tha
  String? get photoFullUrl {
    final p = photoUrl?.trim() ?? '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return null;
  }

  /// ISO ("1990-01-31T18:30:00Z") aur "01-02-1990" dono handle karta hai
  String get dobFormatted {
    if (dob.isEmpty) return '—';
    final ddmmyyyy = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    if (ddmmyyyy.hasMatch(dob)) return dob;
    try {
      final d = DateTime.parse(dob).toLocal();
      return '${d.day.toString().padLeft(2, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.year}';
    } catch (_) {
      return dob;
    }
  }
}

class AlumniListResponse {
  final List<AdminAlumniProfile> alumni;
  final List<String> years;

  AlumniListResponse({required this.alumni, required this.years});
}

// ==================== API SERVICE ====================

class AlumniApiService {
  static Future<AlumniListResponse> fetchAlumniList({String? year}) async {
    final uri = Uri.parse(ApiRoutes.getAlumniProfileList).replace(
      queryParameters:
      (year != null && year.isNotEmpty) ? {'year': year} : null,
    );

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 20));

    debugPrint('ALUMNI URL => $uri');
    debugPrint('ALUMNI BODY => ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to load alumni list (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }
    if (decoded['success'] == false) {
      throw Exception(decoded['message']?.toString() ?? 'API returned false');
    }

    final rawList =
    (decoded['alumni'] ?? decoded['data'] ?? []) as List<dynamic>;

    final alumni = rawList
        .whereType<Map<String, dynamic>>()
        .map(AdminAlumniProfile.fromJson)
        .toList();

    final years = ((decoded['years'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();

    return AlumniListResponse(alumni: alumni, years: years);
  }

}

// ==================== LIST SCREEN ====================

class AdminAlumniListScreen extends StatefulWidget {
  const AdminAlumniListScreen({super.key});

  @override
  State<AdminAlumniListScreen> createState() => _AdminAlumniListScreenState();
}

class _AdminAlumniListScreenState extends State<AdminAlumniListScreen> {
  List<AdminAlumniProfile> _allAlumni = [];
  List<AdminAlumniProfile> _filteredAlumni = [];
  List<String> _years = [];
  String? _selectedYear;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  static const Color _borderRed = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAlumni());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAlumni() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result =
      await AlumniApiService.fetchAlumniList(year: _selectedYear);
      if (!mounted) return;
      setState(() {
        _allAlumni = result.alumni;
        if (result.years.isNotEmpty) _years = result.years;
        _filteredAlumni = _applySearch(_searchController.text);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<AdminAlumniProfile> _applySearch(String raw) {
    final query = raw.toLowerCase().trim();
    if (query.isEmpty) return List.of(_allAlumni);
    return _allAlumni.where((a) {
      return a.fullName.toLowerCase().contains(query) ||
          a.email.toLowerCase().contains(query) ||
          a.phone.contains(query) ||
          a.yearOfPassing.contains(query);
    }).toList();
  }

  void _onSearch() {
    if (!mounted) return;
    setState(() {
      _filteredAlumni = _applySearch(_searchController.text);
    });
  }

  void _onYearSelected(String? year) {
    if (_selectedYear == year) return;
    setState(() => _selectedYear = year);
    _loadAlumni();
  }

  void _openProfile(AdminAlumniProfile alumni) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAlumniDetailScreen(alumni: alumni),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textwhite,
      appBar: AppBar(
        title: const Text('Alumni List'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textwhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlumni,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search name...',
                        hintStyle: const TextStyle(fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: AppColors.grey),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                            : null,
                        filled: true,
                        fillColor: AppColors.textwhite,
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.textwhite,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedYear,
                      hint: const Text('Year', style: TextStyle(fontSize: 14)),
                      icon: Icon(Icons.arrow_drop_down,
                          color: AppColors.primary),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textblack,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Years'),
                        ),
                        ..._years.map(
                              (y) => DropdownMenuItem<String?>(
                            value: y,
                            child: Text(y),
                          ),
                        ),
                      ],
                      onChanged: _onYearSelected,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filteredAlumni.length} alumni found'
                      '${_selectedYear != null ? ' • Batch $_selectedYear' : ''}',
                  style: const TextStyle(color: AppColors.grey, fontSize: 13),
                ),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textwhite,
                ),
                onPressed: _loadAlumni,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_filteredAlumni.isEmpty) {
      return const Center(child: Text('No alumni found'));
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadAlumni,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
          childAspectRatio: 0.92,
        ),
        itemCount: _filteredAlumni.length,
        itemBuilder: (context, index) {
          final alumni = _filteredAlumni[index];
          return _AlumniGridCell(
            alumni: alumni,
            borderColor: _borderRed,
            onTap: () => _openProfile(alumni),
          );
        },
      ),
    );
  }
}

// ==================== GRID CELL ====================

class _AlumniGridCell extends StatelessWidget {
  final AdminAlumniProfile alumni;
  final Color borderColor;
  final VoidCallback onTap;

  const _AlumniGridCell({
    required this.alumni,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = alumni.photoFullUrl;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.textwhite,
          border: Border.all(color: borderColor, width: 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2.5),
              ),
              child: CircleAvatar(
                radius: 38,
                backgroundColor: const Color(0xFF546E8B),
                backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl) : null,
                // FIX: image load fail ho to crash ki jagah icon dikhao
                onBackgroundImageError:
                photoUrl != null ? (_, __) {} : null,
                child: photoUrl == null
                    ? const Icon(Icons.person,
                    size: 48, color: Color(0xFFE8EAF0))
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              alumni.fullName.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textblack,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              alumni.classPassed.isEmpty ? '—' : alumni.classPassed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
              const TextStyle(fontSize: 12, color: AppColors.textblack),
            ),
            Text(
              alumni.dobFormatted,
              style:
              const TextStyle(fontSize: 12, color: AppColors.textblack),
            ),
            if (alumni.yearOfPassing.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '(${alumni.yearOfPassing})',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textblack),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== PROFILE DETAIL SCREEN ====================

class AdminAlumniDetailScreen extends StatelessWidget {
  final AdminAlumniProfile alumni;

  const AdminAlumniDetailScreen({super.key, required this.alumni});

  static const Color _accentRed = Color(0xFFE53935);

  String _v(String value) => value.trim().isEmpty ? '—' : value.trim();

  @override
  Widget build(BuildContext context) {
    // List API mein hi pura data aata hai — koi alag fetch nahi chahiye
    final AdminAlumniProfile _profile = alumni;
    final photoUrl = _profile.photoFullUrl;

    return Scaffold(
      backgroundColor: AppColors.textwhite,
      appBar: AppBar(
        title: const Text('Alumni Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textwhite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ---------- Header ----------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _accentRed, width: 3),
                      color: AppColors.textwhite,
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF546E8B),
                      backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                      onBackgroundImageError:
                      photoUrl != null ? (_, __) {} : null,
                      child: photoUrl == null
                          ? const Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFFE8EAF0),
                      )
                          : null,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _profile.fullName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        Text(
                          _profile.classPassed.isEmpty &&
                              _profile.yearOfPassing.isEmpty
                              ? _v(_profile.email)
                              : '${_v(_profile.classPassed)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _DetailSection(
              title: 'Personal Details',
              children: [
                _DetailRow(
                    icon: Icons.cake_outlined,
                    label: 'Date of Birth',
                    value: _profile.dobFormatted),
                _DetailRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _v(_profile.email)),
                _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: _v(_profile.phone)),
                _DetailRow(
                    icon: Icons.home_outlined,
                    label: 'Address',
                    value: _v(_profile.address)),
                _DetailRow(
                    icon: Icons.location_city_outlined,
                    label: 'City',
                    value: _v(_profile.city)),
              ],
            ),
            _DetailSection(
              title: 'School Details',
              children: [
                _DetailRow(
                    icon: Icons.school_outlined,
                    label: 'Class Passed',
                    value: _v(_profile.classPassed)),
                _DetailRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Year of Passing',
                    value: _v(_profile.yearOfPassing)),
                _DetailRow(
                    icon: Icons.grid_view_outlined,
                    label: 'Section',
                    value: _v(_profile.section)),
                _DetailRow(
                    icon: Icons.flag_outlined,
                    label: 'House',
                    value: _v(_profile.house)),
                _DetailRow(
                    icon: Icons.menu_book_outlined,
                    label: 'Favourite Subject',
                    value: _v(_profile.favouriteSubject)),
                _DetailRow(
                    icon: Icons.person_outline,
                    label: 'Favourite Teacher',
                    value: _v(_profile.favouriteTeacher)),
              ],
            ),
            _DetailSection(
              title: 'Professional Details',
              children: [
                _DetailRow(
                    icon: Icons.work_outline,
                    label: 'Occupation',
                    value: _v(_profile.occupation)),
                _DetailRow(
                    icon: Icons.business_outlined,
                    label: 'Organisation',
                    value: _v(_profile.organisation)),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------- Section card ----------

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.textwhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------- Single detail row ----------

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                  const TextStyle(fontSize: 11, color: AppColors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textblack,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}