import 'package:animated_search_bar/animated_search_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../CommonCalling/data_not_found.dart';
import '../../../CommonCalling/progressbarWhite.dart';
import '../../../constants.dart';
import 'chat.dart';

class NewTeacherMessageScreen extends StatefulWidget {
  final int? messageSendPermissionsApp;

  const NewTeacherMessageScreen({
    super.key,
    required this.messageSendPermissionsApp,
  });

  @override
  State<NewTeacherMessageScreen> createState() =>
      _NewTeacherMessageScreenState();
}

class _NewTeacherMessageScreenState extends State<NewTeacherMessageScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // ─── Scroll controller for students infinite scroll ───
  final ScrollController _studentScrollController = ScrollController();

  bool isLoading = false;
  List messsage = [];   // teachers
  List students = [];   // students (accumulated across pages)
  List filteredMessages = [];
  List filteredMessages2 = [];
  Set<String> selectedTeachers = {};
  Set<String> selectedStudents = {};
  late TabController _tabController;
  bool selectAllTeachers = false;
  bool selectAllStudents = false;
  PlatformFile? selectedFile;
  bool isSending = false;

  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> section = [];
  int? selectedClass;
  int? selectedSection;

  // ─── Pagination state for students ───
  int _studentCurrentPage = 1;
  int _studentLastPage = 1;
  int _studentTotalCount = 0; // total from pagination
  bool _isLoadingMoreStudents = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterMessages);
    _tabController.addListener(_onTabChanged);

    // ─── Infinite scroll listener ───
    _studentScrollController.addListener(() {
      if (_studentScrollController.position.pixels >=
          _studentScrollController.position.maxScrollExtent - 200) {
        _loadMoreStudents();
      }
    });

    fetchClasses();
  }

  void _onTabChanged() {
    setState(() {
      _searchController.clear();
      _filterMessages();
    });
  }

  List<Map<String, dynamic>> _asMapList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<void> fetchClasses() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('teachertoken');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No token found. Please log in.')),
        );
        return;
      }

      final response = await http.get(
        Uri.parse(ApiRoutes.getTeacherTeacherSubject),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData =
        json.decode(response.body) as Map<String, dynamic>;

        final parsedClasses = _asMapList(responseData['classes']);
        final parsedSections = _asMapList(responseData['sections']);

        if (!mounted) return;
        setState(() {
          classes = parsedClasses;
          section = parsedSections;
          isLoading = false;
        });

        _checkForDuplicateIds(classes, 'classes');
        await fetchAssignmentsData(resetPage: true);
      } else {
        throw Exception(
            'Failed to load class and section data (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching classes and sections: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching classes: $e')),
      );
    }
  }

  void _checkForDuplicateIds(
      List<Map<String, dynamic>> list, String listName) {
    final idSet = <int>{};
    for (var item in list) {
      final id = item['id'] as int;
      if (idSet.contains(id)) {
        debugPrint('Warning: Duplicate ID $id found in $listName');
      } else {
        idSet.add(id);
      }
    }
  }

  // ─── Main fetch (page 1 reset) ───
  Future<void> fetchAssignmentsData({bool resetPage = false}) async {
    if (resetPage) {
      _studentCurrentPage = 1;
      students = [];
    }

    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    if (token == null) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No token found. Please log in.')),
      );
      return;
    }

    try {
      final queryParams = <String, String>{
        'page': _studentCurrentPage.toString(),
      };
      if (selectedClass != null) {
        queryParams['class_id'] = selectedClass.toString();
      }

      final uri = Uri.parse(ApiRoutes.getAllTeacherMessages)
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // Teachers only on first page / reset
        if (resetPage || _studentCurrentPage == 1) {
          messsage = jsonResponse['users'] ?? [];
        }

        final newStudents = jsonResponse['students'] ?? [];
        final pagination = jsonResponse['pagination'];

        setState(() {
          if (resetPage) {
            students = newStudents;
          } else {
            students = [...students, ...newStudents];
          }
          _studentLastPage = pagination?['last_page'] ?? 1;
          _studentTotalCount = pagination?['total'] ?? students.length;
          filteredMessages = messsage;
          filteredMessages2 = students;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch data.')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ─── Load next page for students ───
  Future<void> _loadMoreStudents() async {
    if (_isLoadingMoreStudents) return;
    if (_studentCurrentPage >= _studentLastPage) return;
    if (_tabController.index != 1) return; // only when student tab active

    setState(() => _isLoadingMoreStudents = true);

    _studentCurrentPage++;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    if (token == null) {
      setState(() => _isLoadingMoreStudents = false);
      return;
    }

    try {
      final queryParams = <String, String>{
        'page': _studentCurrentPage.toString(),
      };
      if (selectedClass != null) {
        queryParams['class_id'] = selectedClass.toString();
      }

      final uri = Uri.parse(ApiRoutes.getAllTeacherMessages)
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final newStudents = jsonResponse['students'] ?? [];
        final pagination = jsonResponse['pagination'];

        setState(() {
          students = [...students, ...newStudents];
          _studentLastPage = pagination?['last_page'] ?? _studentLastPage;
          _studentTotalCount = pagination?['total'] ?? _studentTotalCount;
          filteredMessages2 = students;
          _isLoadingMoreStudents = false;
        });
      } else {
        setState(() {
          _studentCurrentPage--; // rollback
          _isLoadingMoreStudents = false;
        });
      }
    } catch (e) {
      setState(() {
        _studentCurrentPage--;
        _isLoadingMoreStudents = false;
      });
    }
  }

  void _filterMessages() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (_tabController.index == 0) {
        filteredMessages = messsage.where((assignment) {
          final name =
              assignment['first_name']?.toString().toLowerCase() ?? '';
          final designation =
              assignment['designation']?.toString().toLowerCase() ?? '';
          return name.contains(query) || designation.contains(query);
        }).toList();
      } else {
        filteredMessages2 = students.where((assignment) {
          final name =
              assignment['student_name']?.toString().toLowerCase() ?? '';
          final className =
              assignment['class_name']?.toString().toLowerCase() ?? '';
          return name.contains(query) || className.contains(query);
        }).toList();
      }
    });
  }

  // ─── Send message ───
  Future<void> _sendMessage() async {
    if (isSending) return;

    if (messageController.text.trim().isEmpty && selectedFile == null) {
      _showErrorSnackBar('Please enter a message or select a file');
      return;
    }

    if (widget.messageSendPermissionsApp == 0) {
      _showPermissionDeniedPopup(context);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    if (token == null) {
      _showErrorSnackBar('No authentication token found');
      return;
    }

    setState(() => isSending = true);

    try {
      final uri = Uri.parse(ApiRoutes.sendTeacherMessage);
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // ─── Select All flags ───
      if (selectAllTeachers) {
        request.fields['all_teachers'] = 'true';
      } else {
        request.fields['all_teachers'] = 'false';
      }

      // ─── Students: class selected hai to IDs bhejo, nahi to flag ───
      if (selectAllStudents && selectedClass == null) {
        // No class filter → all_students: true, backend sab bhejega
        request.fields['all_students'] = 'true';
      } else {
        request.fields['all_students'] = 'false';
      }

      // ─── Receivers array ───
      List<String> receivers = [];
      if (!selectAllTeachers) receivers.addAll(selectedTeachers);
      // Class selected + selectAll → selectedStudents mein IDs hain
      // Class nahi + selectAll → all_students=true, IDs mat bhejo
      if (!(selectAllStudents && selectedClass == null)) {
        receivers.addAll(selectedStudents);
      }
      request.fields['receivers'] = jsonEncode(receivers);

      debugPrint('🚀 ═══════════════ SEND MESSAGE ═══════════════');
      debugPrint('📨 [BODY] ${messageController.text.trim()}');
      debugPrint('📎 [FILE] ${selectedFile?.name ?? "No file"}');
      debugPrint('👩‍🏫 [ALL_TEACHERS] ${request.fields['all_teachers']}');
      debugPrint('👨‍🎓 [ALL_STUDENTS] ${request.fields['all_students']}');
      debugPrint('🎓 [SELECTED CLASS] $selectedClass');
      debugPrint('👥 [RECEIVERS] $receivers');
      debugPrint('🔢 [RECEIVERS COUNT] ${receivers.length}');
      debugPrint('═══════════════════════════════════════════════');

      request.fields['body'] = messageController.text.trim();

      if (selectedFile != null && selectedFile!.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            selectedFile!.path!,
            filename: selectedFile!.name,
          ),
        );
      } else {
        request.fields['attachment'] = '';
      }

      final response = await request.send();

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        messageController.clear();
        setState(() {
          selectedFile = null;
          selectedTeachers.clear();
          selectedStudents.clear();
          selectAllTeachers = false;
          selectAllStudents = false;
        });
        _showSuccessPopup(context);
      } else {
        _showErrorSnackBar('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error sending message: $e');
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showPermissionDeniedPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          elevation: 8.0,
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey[50]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.lock_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Permission Denied',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black87,
                        letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Sorry, you don\'t have permission to send messages at this time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
                  ),
                ),
                const SizedBox(height: 24),
                Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: const Text(
                      'Close',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_tabController.index == 0) {
        final teacherId = "user_$id";
        if (selectedTeachers.contains(teacherId)) {
          selectedTeachers.remove(teacherId);
          debugPrint('🔴 [TEACHER DESELECTED] id=$teacherId');
        } else {
          selectedTeachers.add(teacherId);
          debugPrint('✅ [TEACHER SELECTED] id=$teacherId');
        }
        selectAllTeachers = selectedTeachers.length == messsage.length;
        debugPrint('📋 [TEACHERS SELECTED] total=${selectedTeachers.length}/${messsage.length} | selectAll=$selectAllTeachers');
        debugPrint('📦 [TEACHERS LIST] $selectedTeachers');
      } else {
        final studentId = "student_$id";
        if (selectedStudents.contains(studentId)) {
          selectedStudents.remove(studentId);
          debugPrint('🔴 [STUDENT DESELECTED] id=$studentId');
        } else {
          selectedStudents.add(studentId);
          debugPrint('✅ [STUDENT SELECTED] id=$studentId');
        }
        selectAllStudents = selectedStudents.length == students.length;
        debugPrint('📋 [STUDENTS SELECTED] total=${selectedStudents.length}/${students.length} | selectAll=$selectAllStudents');
        debugPrint('📦 [STUDENTS LIST] $selectedStudents');
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_tabController.index == 0) {
        if (selectAllTeachers) {
          selectedTeachers.clear();
          selectAllTeachers = false;
          debugPrint('🔴 [SELECT ALL TEACHERS] → DESELECTED ALL');
        } else {
          selectedTeachers.addAll(messsage.map((u) => "user_${u['id']}"));
          selectAllTeachers = true;
          debugPrint('✅ [SELECT ALL TEACHERS] → ALL SELECTED | count=${selectedTeachers.length}');
          debugPrint('📦 [TEACHERS LIST] $selectedTeachers');
        }
      } else {
        if (selectAllStudents) {
          selectedStudents.clear();
          selectAllStudents = false;
          debugPrint('🔴 [SELECT ALL STUDENTS] → DESELECTED ALL');
        } else {
          if (selectedClass != null) {
            // ─── Class selected → sirf loaded students ke IDs add karo ───
            selectedStudents.clear();
            selectedStudents.addAll(students.map((s) => "student_${s['id']}"));
            selectAllStudents = true;
            debugPrint('✅ [SELECT ALL STUDENTS] Class=$selectedClass selected → IDs add kiye');
            debugPrint('📋 [STUDENTS SELECTED] count=${selectedStudents.length}/${students.length}');
            debugPrint('📦 [STUDENTS LIST] $selectedStudents');
            debugPrint('🚩 [API WILL SEND] all_students=false | receivers=${selectedStudents.toList()}');
          } else {
            // ─── No class → sirf flag true, backend sab handle karega ───
            selectedStudents.clear();
            selectAllStudents = true;
            debugPrint('✅ [SELECT ALL STUDENTS] No class selected → only flag set');
            debugPrint('🚩 [API WILL SEND] all_students=true | receivers=[]');
          }
        }
      }
    });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => selectedFile = result.files.first);
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
    }
  }

  void _showSuccessPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.1)),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 50),
                ),
                const SizedBox(height: 15),
                const Text("Success 🎉",
                    style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Message sent successfully!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("OK",
                        style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(35.sp),
        child: AppBar(
          backgroundColor: AppColors.secondary,
          centerTitle: true,
          leading: SizedBox(
            height: 50.sp,
            child: Center(
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white, size: 25.sp),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          title: SizedBox(
            width: MediaQuery.of(context).size.width * 0.95,
            height: 30.sp,
            child: AnimatedSearchBar(
              label: 'Compose Messages',
              controller: _searchController,
              labelStyle: GoogleFonts.montserrat(
                textStyle: Theme.of(context).textTheme.displayLarge,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textwhite,
              ),
              searchStyle: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              closeIcon: const Icon(Icons.close, color: Colors.white),
              searchIcon: const Icon(Icons.search, color: Colors.white),
              textInputAction: TextInputAction.done,
              autoFocus: false,
              searchDecoration: const InputDecoration(
                hintText: 'Search',
                alignLabelWithHint: true,
                fillColor: Colors.white,
                focusColor: Colors.white,
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() {}),
              onFieldSubmitted: (value) => setState(() {}),
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 8.sp),
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  messageController.clear();
                  setState(() {
                    selectedFile = null;
                    selectedTeachers.clear();
                    selectedStudents.clear();
                    selectAllTeachers = false;
                    selectAllStudents = false;
                    selectedClass = null;
                    selectedSection = null;
                  });
                  fetchAssignmentsData(resetPage: true);
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Tab Bar ───
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(25.0),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(25.0),
                color: Colors.red.shade800,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              labelStyle: TextStyle(
                  fontSize: 15.sp, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(
                  fontSize: 13.sp, fontWeight: FontWeight.bold),
              unselectedLabelColor: Colors.black,
              tabs: [
                Tab(
                  child: Container(
                    alignment: Alignment.center,
                    child: Text('Teachers (${filteredMessages.length})',
                        textAlign: TextAlign.center),
                  ),
                ),
                Tab(
                  child: Container(
                    alignment: Alignment.center,
                    child: Text('Students ($_studentTotalCount)',
                        textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),

          // ─── Class Filter (Students tab only) ───
          Visibility(
            visible: _tabController.index == 1,
            child: Card(
              color: Colors.white70,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.sp, vertical: 5.sp),
                            child: Text('Class',
                                style: GoogleFonts.montserrat(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black)),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.sp),
                            child: Container(
                              width: double.infinity,
                              height: 40.sp,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: FocusScope(
                                        canRequestFocus: false,
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButtonFormField<int?>(
                                            value: classes.isNotEmpty &&
                                                classes.any((c) =>
                                                c["id"] == selectedClass)
                                                ? selectedClass
                                                : null,
                                            decoration: const InputDecoration(
                                              hintText: "Select Class",
                                              border: InputBorder.none,
                                              contentPadding:
                                              EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 0),
                                            ),
                                            icon: const SizedBox.shrink(),
                                            items: classes.isNotEmpty
                                                ? classes.map((c) {
                                              return DropdownMenuItem<int>(
                                                value: c["id"],
                                                child: Text(
                                                    '${c["academic_class"]['title']}(${c["section"]['title']})'),
                                              );
                                            }).toList()
                                                : [
                                              const DropdownMenuItem<int>(
                                                value: null,
                                                child: Text(
                                                    "No Classes Available"),
                                              ),
                                            ],
                                            onChanged: classes.isNotEmpty
                                                ? (value) {
                                              debugPrint('🏫 [CLASS CHANGED] selectedClass=$value');
                                              setState(() {
                                                selectedClass = value;
                                                // Reset students on class change
                                                selectedStudents.clear();
                                                selectAllStudents = false;
                                              });
                                              debugPrint('🔄 [RESET] selectedStudents cleared, selectAllStudents=false');
                                              fetchAssignmentsData(
                                                  resetPage: true);
                                            }
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Center(
                                      child: Icon(Icons.arrow_drop_down,
                                          size: 24, color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
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

          SizedBox(height: 10.sp),

          // ─── Select All row ───
          Align(
            alignment: Alignment.topLeft,
            child: Card(
              color: Colors.grey.shade100,
              child: SizedBox(
                width: 150.sp,
                height: 30.sp,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 10.sp, vertical: 5.sp),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _tabController.index == 0
                            ? selectAllTeachers
                            : selectAllStudents,
                        onChanged: (value) => _toggleSelectAll(),
                        activeColor: AppColors.primary,
                      ),
                      Text(
                        'Select All',
                        style: GoogleFonts.montserrat(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 10.sp),

          // ─── Tab Content ───
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Teachers Tab ──
                isLoading
                    ? const WhiteCircularProgressWidget()
                    : filteredMessages.isEmpty
                    ? const Center(
                    child: DataNotFoundWidget(
                        title: 'No Teachers Found.'))
                    : ListView.builder(
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    final assignment = filteredMessages[index];
                    final isSelected = selectedTeachers
                        .contains('user_${assignment['id']}');
                    return GestureDetector(
                      onLongPress: () =>
                          _toggleSelection(assignment['id']),
                      child: Card(
                        margin: EdgeInsets.symmetric(
                            vertical: 3.sp, horizontal: 5.sp),
                        color: isSelected
                            ? Colors.blue.shade50
                            : Colors.white,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(10.sp)),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (value) =>
                                  _toggleSelection(assignment['id']),
                              activeColor: AppColors.primary,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    assignment['first_name']
                                        ?.toString()
                                        .toUpperCase() ??
                                        'UNKNOWN',
                                    style: GoogleFonts.montserrat(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '(${assignment['designation'].toString().toUpperCase()})',
                                    style: GoogleFonts.montserrat(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // ── Students Tab with infinite scroll ──
                isLoading
                    ? const WhiteCircularProgressWidget()
                    : filteredMessages2.isEmpty
                    ? const Center(
                    child: DataNotFoundWidget(
                        title: 'No Students Found.'))
                    : ListView.builder(
                  controller: _studentScrollController,
                  // +1 for the loading indicator at bottom
                  itemCount: filteredMessages2.length +
                      (_isLoadingMoreStudents ? 1 : 0),
                  itemBuilder: (context, index) {
                    // ─── Bottom loader ───
                    if (index == filteredMessages2.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                            child: CircularProgressIndicator(color: Colors.white,)),
                      );
                    }

                    final assignment = filteredMessages2[index];
                    final isSelected = selectAllStudents ||
                        selectedStudents.contains(
                            'student_${assignment['id']}');
                    return GestureDetector(
                      onLongPress: () =>
                          _toggleSelection(assignment['id']),
                      child: Card(
                        margin: EdgeInsets.symmetric(
                            vertical: 3.sp, horizontal: 5.sp),
                        color: isSelected
                            ? Colors.blue.shade50
                            : Colors.white,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(11.sp)),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (value) =>
                                  _toggleSelection(assignment['id']),
                              activeColor: AppColors.primary,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    assignment['student_name']
                                        ?.toString()
                                        .toUpperCase() ??
                                        'UNKNOWN',
                                    style: GoogleFonts.montserrat(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${assignment['class']?.toString().toUpperCase()}',
                                    style: GoogleFonts.montserrat(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ─── Message Input ───
          SafeArea(
            child: Card(
              color: Colors.grey.shade300,
              margin: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  topRight: Radius.circular(0),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 5.sp, vertical: 15.sp),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file,
                          color: AppColors2.primary),
                      onPressed: _pickFile,
                    ),
                    Expanded(
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: messageController,
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            if (selectedFile != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  selectedFile!.name,
                                  style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: AppColors2.primary,
                      child: IconButton(
                        icon: isSending
                            ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: isSending ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    messageController.dispose();
    _tabController.dispose();
    _studentScrollController.dispose();
    super.dispose();
  }
}