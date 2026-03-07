import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────
// THEME COLORS
// ─────────────────────────────────────────────
const Color kPrimary = Color(0xFFD32F2F);      // red
const Color kPrimaryDark = Color(0xFFB71C1C);
const Color kPrimaryLight = Color(0xFFFFEBEE);
const Color kLabelColor = Color(0xFF9E9E9E);
const Color kValueColor = Color(0xFF212121);
const Color kLinkColor = Color(0xFFD32F2F);
const Color kBgColor = Color(0xFFF2F2F2);

// ─────────────────────────────────────────────
// TIMETABLE MODEL
// ─────────────────────────────────────────────
class TimetableSlot {
  final int id;
  final int period;
  final int day;
  final String subjectName;
  final String className;
  final String section;

  TimetableSlot({
    required this.id,
    required this.period,
    required this.day,
    required this.subjectName,
    required this.className,
    required this.section,
  });

  factory TimetableSlot.fromJson(Map<String, dynamic> json) => TimetableSlot(
    id: json['id'] ?? 0,
    period: json['period'] ?? 0,
    day: json['day'] ?? 0,
    subjectName: json['subject_name'] ?? '',
    className: json['class'] ?? '',
    section: json['section'] ?? '',
  );

  String get classSection => '$className-$section';
}

// ─────────────────────────────────────────────
// STAFF MODEL
// ─────────────────────────────────────────────
class StaffModel {
  final int id;
  final String staffId;
  final String empId;
  final String title;
  final String firstName;
  final String? lastName;
  final String email;
  final String phone;
  final String gender;
  final String dob;
  final String joiningDate;
  final String? qualification;
  final String? maritalStatus;
  final String? nationality;
  final String? religion;
  final String? permanentAddress;
  final String? pan;
  final String? nationalId;
  final String? photo;
  final String? uan;
  final String? bankAccountNo;
  final String? bankName;
  final double? basicSalary;
  final String? fsName;
  final String? fsRelation;
  final String? fsPhone;

  StaffModel({
    required this.id,
    required this.staffId,
    required this.empId,
    required this.title,
    required this.firstName,
    this.lastName,
    required this.email,
    required this.phone,
    required this.gender,
    required this.dob,
    required this.joiningDate,
    this.qualification,
    this.maritalStatus,
    this.nationality,
    this.religion,
    this.permanentAddress,
    this.pan,
    this.nationalId,
    this.photo,
    this.uan,
    this.bankAccountNo,
    this.bankName,
    this.basicSalary,
    this.fsName,
    this.fsRelation,
    this.fsPhone,
  });

  String get fullName {
    final last = (lastName != null && lastName!.isNotEmpty) ? ' $lastName' : '';
    return '$title $firstName$last';
  }

  factory StaffModel.fromJson(Map<String, dynamic> j) {
    const genderMap = {1: 'Male', 2: 'Female', 3: 'Other'};
    const maritalMap = {1: 'Single', 2: 'Married', 3: 'Divorced'};
    const religionMap = {
      1: 'Hindu', 2: 'Muslim', 3: 'Christian', 4: 'Sikh', 5: 'Other'
    };
    return StaffModel(
      id: j['id'] ?? 0,
      staffId: j['staff_id'] ?? '',
      empId: j['emp_id'] ?? '',
      title: j['title'] ?? '',
      firstName: j['first_name'] ?? '',
      lastName: j['last_name'],
      email: j['email'] ?? '',
      phone: j['phone'] ?? '',
      gender: genderMap[j['gender']] ?? 'N/A',
      dob: j['dob'] ?? '',
      joiningDate: j['joining_date'] ?? '',
      qualification: j['qualification'],
      maritalStatus: maritalMap[j['marital_status']],
      nationality: j['nationality'],
      religion: religionMap[j['religion']],
      permanentAddress: j['permanent_address'],
      pan: j['PAN'],
      nationalId: j['national_id'],
      photo: j['photo'],
      uan: j['UAN'],
      bankAccountNo: j['bank_account_no'],
      bankName: j['bankName'],
      basicSalary: (j['basic_salary'] as num?)?.toDouble(),
      fsName: j['fs_name'],
      fsRelation: j['fs_relation'],
      fsPhone: j['fs_phone'],
    );
  }
}

// ─────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────
class StaffProfileScreen extends StatefulWidget {
  final int staffId;

  const StaffProfileScreen({
    Key? key,
    required this.staffId,
  }) : super(key: key);

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  StaffModel? _staff;
  List<TimetableSlot> _timetable = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final url = '${ApiRoutes.getTeacheProfile}/${widget.staffId}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          final ttJson = (data['timetable'] as List<dynamic>?) ?? [];
          setState(() {
            _staff = StaffModel.fromJson(data['user']);
            _timetable = ttJson.map((e) => TimetableSlot.fromJson(e)).toList();
            _isLoading = false;
          });
          return;
        }
      }
      setState(() { _error = 'Failed to load staff data'; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Staff Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _error != null
          ? _buildError()
          : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // ── Profile header (like screenshot: avatar left, info right) ──
        _buildProfileHeader(),
        // ── Tab content ──
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _PersonalDetailsTab(staff: _staff!),
              _TimetableTab(slots: _timetable),
            ],
          ),
        ),
        // ── Bottom Tab Bar (exactly like screenshot style) ──
        _buildBottomTabBar(),
      ],
    );
  }

  // ── PROFILE HEADER — same as screenshot layout ──
  Widget _buildProfileHeader() {
    final staff = _staff!;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar circle
          Container(
            width: 100.sp,
            height: 100.sp,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: ClipOval(
              child: (staff.photo != null && staff.photo!.isNotEmpty)
                  ? Image.network(
                staff.photo!,
                // fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  size: 40,
                  color: Color(0xFF9E9E9E),
                ),
              )
                  : const Icon(Icons.person, size: 40, color: Color(0xFF9E9E9E)),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.fullName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: kValueColor,
                  ),
                ),
                const SizedBox(height: 3),
                _headerRow('Designation:', 'Teacher'),
                _headerRow('Gender', staff.gender),
                _headerRow('DOJ:', _fmt(staff.joiningDate)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: kLabelColor),
          children: [
            TextSpan(text: '$label  '),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: kValueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM TAB BAR — exactly like screenshot ──
  Widget _buildBottomTabBar() {
    final labels = ['Personal Details','Timetable'];
    return Container(
      color: Colors.grey.shade300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return Row(
                  children: List.generate(labels.length, (i) {
                    final selected = _tabController.index == i;
                    return GestureDetector(
                      onTap: () {
                        _tabController.animateTo(i);
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 25),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: selected ? kPrimary : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: selected ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String raw) {
    try {
      final p = raw.split('-');
      if (p.length < 3) return raw;
      const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${p[2]}-${m[int.tryParse(p[1]) ?? 0]}-${p[0]}';
    } catch (_) { return raw; }
  }
}

// ─────────────────────────────────────────────
// TAB 1 — PERSONAL DETAILS (exactly like screenshot layout)
// ─────────────────────────────────────────────
class _PersonalDetailsTab extends StatelessWidget {
  final StaffModel staff;
  const _PersonalDetailsTab({required this.staff});

  @override
  Widget build(BuildContext context) {
    return ListView(
      // backgroundColor: kBgColor,
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 10),
        _twoColSection([
          _TwoColItem(label: 'Date of Birth', value: _fmt(staff.dob)),
          _TwoColItem(label: 'CBSE ID', value: ''),
        ]),
        _divider(),
        _twoColSection([
          _TwoColItem(label: 'Qualification', value: staff.qualification ?? ''),
          _TwoColItem(label: 'Marital Status', value: staff.maritalStatus ?? ''),
        ]),
        _divider(),
        _twoColSection([
          _TwoColItem(label: 'Religion', value: staff.religion ?? ''),
          _TwoColItem(label: 'Nationality', value: staff.nationality ?? ''),
        ]),
        _divider(),
        _twoColSection([
          _TwoColItem(
              label: 'Aadhar Card Number',
              value: staff.nationalId ?? ''),
          _TwoColItem(label: 'PAN', value: staff.pan ?? ''),
        ]),
        _divider(),
        _twoColSection([
          _TwoColItem(
              label: 'Contact No:',
              value: staff.phone,
              isLink: true),
          _TwoColItem(
              label: 'email ID',
              value: staff.email,
              isLink: true),
        ]),
        _divider(),
        _twoColSection([
          _TwoColItem(
              label: 'Address',
              value: staff.permanentAddress ?? ''),
          _TwoColItem(label: 'National Teacher ID', value: ''),
        ]),
        _divider(),
        _singleSection('State Teacher ID:', ''),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _twoColSection(List<_TwoColItem> items) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                      fontSize: 12, color: kLabelColor),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value.isEmpty ? '' : item.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: item.isLink ? kLinkColor : kValueColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _singleSection(String label, String value) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: kLabelColor)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kValueColor),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
    height: 1,
    thickness: 1,
    color: Color(0xFFF0F0F0),
    indent: 0,
    endIndent: 0,
  );

  String _fmt(String raw) {
    try {
      final p = raw.split('-');
      if (p.length < 3) return raw;
      const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${p[2]}-${m[int.tryParse(p[1]) ?? 0]}-${p[0]}';
    } catch (_) { return raw; }
  }
}

class _TwoColItem {
  final String label;
  final String value;
  final bool isLink;
  const _TwoColItem(
      {required this.label, required this.value, this.isLink = false});
}


// ─────────────────────────────────────────────
// TAB 4 — TIMETABLE
// ─────────────────────────────────────────────
class _TimetableTab extends StatefulWidget {
  final List<TimetableSlot> slots;
  const _TimetableTab({required this.slots});

  @override
  State<_TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<_TimetableTab> {
  static const Map<int, String> _dayNames = {
    1: 'Monday', 2: 'Tuesday', 3: 'Wednesday',
    4: 'Thursday', 5: 'Friday',
  };

  int _selectedDay = 1;

  List<int> get _availableDays =>
      widget.slots.map((s) => s.day).toSet().toList()..sort();

  List<TimetableSlot> get _filtered => widget.slots
      .where((s) => s.day == _selectedDay)
      .toList()
    ..sort((a, b) => a.period.compareTo(b.period));

  @override
  void initState() {
    super.initState();
    final days = _availableDays;
    if (days.isNotEmpty) _selectedDay = days.first;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slots.isEmpty) {
      return Center(
        child: Text('No timetable assigned',
            style: TextStyle(color: Colors.grey[500])),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 5.sp,
        ),
        _buildDaySelector(),
        Expanded(child: _buildSlotList()),
      ],
    );
  }

  Widget _buildDaySelector() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _availableDays.map((day) {
            final selected = day == _selectedDay;
            return GestureDetector(
              onTap: () => setState(() => _selectedDay = day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? kPrimary : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _dayNames[day]?.substring(0, 3) ?? 'D$day',
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey[700],
                    fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSlotList() {
    final slots = _filtered;
    if (slots.isEmpty) {
      return Center(
        child: Text('No classes on ${_dayNames[_selectedDay]}',
            style: TextStyle(color: Colors.grey[500])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: slots.length,
      itemBuilder: (_, i) => _slotCard(slots[i]),
    );
  }

  Widget _slotCard(TimetableSlot slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: const BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('P',
                    style: TextStyle(color: Colors.white, fontSize: 10,fontWeight: FontWeight.bold)),
                Text('${slot.period}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slot.subjectName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: kValueColor)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(Icons.class_outlined, 'Class ${slot.className}'),
                      const SizedBox(width: 8),
                      _chip(Icons.group_outlined, 'Sec ${slot.section}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: kPrimary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

