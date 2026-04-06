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

  final ScrollController _studentScrollController = ScrollController();

  bool isLoading = false;
  List messsage = [];
  List students = [];
  List filteredMessages = [];
  List filteredMessages2 = [];
  Set<String> selectedTeachers = {};
  Set<String> selectedStudents = {};
  late TabController _tabController;
  bool selectAllTeachers = false;
  bool selectAllStudents = false;
  PlatformFile? selectedFile;
  bool isSending = false;
  bool isPolling = false;


  List<int> selectedClasses = [];
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> section = [];
  int? selectedClass;
  int? selectedSection;

  int _studentCurrentPage = 1;
  int _studentLastPage = 1;
  int _studentTotalCount = 0;
  bool _isLoadingMoreStudents = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterMessages);
    _tabController.addListener(_onTabChanged);

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

      if (selectedClasses.isNotEmpty) {
        queryParams['class_id'] = selectedClasses.join(',');
      }

      final uri = Uri.parse(ApiRoutes.getAllTeacherMessages)
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

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

  Future<void> _loadMoreStudents() async {
    if (_isLoadingMoreStudents) return;
    if (_studentCurrentPage >= _studentLastPage) return;
    if (_tabController.index != 1) return;

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
          _studentCurrentPage--;
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

  Future<void> _sendMessage() async {
    if (isSending) return;

    final text = messageController.text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (text.isEmpty && selectedFile == null) {
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

      request.fields['all_teachers'] = selectAllTeachers ? 'true' : 'false';
      request.fields['all_students'] = 'false';

      List<String> receivers = [];

      if (!selectAllTeachers) receivers.addAll(selectedTeachers);

      receivers.addAll(
        selectedStudents
            .where((e) => e != null)
            .map((e) => e.toString()),
      );

      request.fields['receivers'] = jsonEncode(receivers);
      request.fields['body'] = text;

      if (selectedFile != null && selectedFile!.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            selectedFile!.path!,
            filename: selectedFile!.name,
          ),
        );
      }

      final response = await request.send();
      final responseData = await http.Response.fromStream(response);

      if (!mounted) return;

      // ✅ DIRECT SUCCESS
      if (response.statusCode == 200 || response.statusCode == 201) {
        _resetUI();
        _showSuccessPopup(context);
      }

      // ✅ BACKGROUND JOB
      else if (response.statusCode == 202) {
        final data = jsonDecode(responseData.body);

        String jobKey = data['job_key']?.toString() ?? '';

        if (jobKey.isEmpty) {
          _showErrorSnackBar("Something went wrong");
          setState(() => isSending = false);
          return;
        }

        // 🔥 START POLLING
        isPolling = true;
        checkMessageStatus(jobKey);
      }

      else {
        _showErrorSnackBar('Failed: ${response.statusCode}');
        setState(() => isSending = false);
      }

    } catch (e) {
      _showErrorSnackBar('Error: $e');
      setState(() => isSending = false);
    }

    finally {
      // ❗ ONLY STOP if NOT polling
      if (!isPolling && mounted) {
        setState(() => isSending = false);
      }
    }
  }
  Future<void> checkMessageStatus(String jobKey) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('teachertoken');

    if (token == null) return;

    int maxAttempts = 4;
    int attempt = 0;

    while (attempt < maxAttempts) {
      await Future.delayed(const Duration(seconds: 5));
      attempt++;

      try {
        final url = Uri.parse("${ApiRoutes.messageSendStatus}$jobKey");

        final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          int statusCode = data['status_code'];

          debugPrint("📡 Attempt $attempt → Status: $statusCode");

          if (statusCode == 2) {
            // ✅ DONE
            _stopLoader();
            _resetUI();
            _showSuccessPopup(context);
            return;
          }

          else if (statusCode == 3) {
            // ❌ FAILED
            _stopLoader();
            _showErrorSnackBar("Message sending failed");
            return;
          }

          else if (statusCode == 4) {
            // ⚠️ NOT FOUND
            _stopLoader();
            _showErrorSnackBar("Job not found");
            return;
          }

          // 🔁 status = 1 → continue
        } else {
          _stopLoader();
          return;
        }
      } catch (e) {
        _stopLoader();
        return;
      }
    }

    // ⏹️ TIMEOUT
    _stopLoader();
    _showErrorSnackBar("Timeout, try again");
  }

  void _stopLoader() {
    if (mounted) {
      setState(() {
        isSending = false;
        isPolling = false;
      });
    }
  }

  void _resetUI() {
    messageController.clear();

    setState(() {
      selectedFile = null;
      selectedTeachers.clear();
      selectedStudents.clear();
      selectAllTeachers = false;
      selectAllStudents = false;
    });
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

  // ✅ FIX: _toggleSelection — students branch mein selectAll ON ho to pehle sab IDs load karo
  void _toggleSelection(int id) {
    setState(() {
      if (_tabController.index == 0) {
        final teacherId = "user_$id";

        if (selectedTeachers.contains(teacherId)) {
          selectedTeachers.remove(teacherId);
          debugPrint('🔴 Teacher removed $teacherId');
        } else {
          selectedTeachers.add(teacherId);
          debugPrint('✅ Teacher added $teacherId');
        }

        selectAllTeachers =
            selectedTeachers.length == filteredMessages.length;
      } else {
        final studentId = "student_$id";

        // ✅ FIX: Agar selectAll ON hai lekin Set empty hai to pehle sab IDs populate karo
        if (selectAllStudents && selectedStudents.isEmpty) {
          selectedStudents.addAll(
              filteredMessages2.map((s) => "student_${s['id']}"));
        }

        if (selectedStudents.contains(studentId)) {
          selectedStudents.remove(studentId);
          debugPrint('🔴 Student removed $studentId');
        } else {
          selectedStudents.add(studentId);
          debugPrint('✅ Student added $studentId');
        }

        selectAllStudents =
            selectedStudents.length == filteredMessages2.length;

        debugPrint('Students Selected: $selectedStudents');
      }
    });
  }

  // ✅ FIX: _toggleSelectAll — students mein bhi sab IDs Set mein daalo (teachers jaisa)
  void _toggleSelectAll() {
    setState(() {
      if (_tabController.index == 0) {
        if (selectAllTeachers) {
          selectedTeachers.clear();
          selectAllTeachers = false;
          debugPrint('🔴 [SELECT ALL TEACHERS] → DESELECTED');
        } else {
          selectedTeachers.clear();
          selectedTeachers
              .addAll(filteredMessages.map((u) => "user_${u['id']}"));
          selectAllTeachers = true;
          debugPrint(
              '✅ [SELECT ALL TEACHERS] → ${selectedTeachers.length} selected');
        }
      } else {
        if (selectAllStudents) {
          // ✅ Deselect: Set clear karo, flag false karo
          selectedStudents.clear();
          selectAllStudents = false;
          debugPrint('🔴 [SELECT ALL STUDENTS] → DESELECTED');
        } else {

          selectedStudents.clear();
          selectedStudents
              .addAll(filteredMessages2.map((s) => "student_${s['id']}"));
          // selectAllStudents = true;  ❌ mat karo — API issue
          selectAllStudents = selectedStudents.length == filteredMessages2.length; // ✅ length se derive hoga
          debugPrint(
              '✅ [SELECT ALL STUDENTS] → ${selectedStudents.length} selected');
          debugPrint('📦 [STUDENTS LIST] $selectedStudents');
          // // ✅ FIX: Teachers ki tarah — sab IDs Set mein daalo
          // selectedStudents.clear();
          // selectedStudents
          //     .addAll(filteredMessages2.map((s) => "student_${s['id']}"));
          // // selectAllStudents = true;
          // debugPrint(
          //     '✅ [SELECT ALL STUDENTS] → ${selectedStudents.length} selected');
          // debugPrint('📦 [STUDENTS LIST] $selectedStudents');
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
                            padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 5.sp),
                            child: Text(
                              'Class',
                              style: GoogleFonts.montserrat(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.sp),
                            child:// Class Selector Widget — Improved UI
                            GestureDetector(
                              onTap: () async {
                                final result = await showDialog<List<int>>(
                                  context: context,
                                  builder: (context) {
                                    List<int> tempSelected = List.from(selectedClasses);
                                    return StatefulBuilder(
                                      builder: (context, setDialogState) {
                                        bool isAllSelected = tempSelected.length == classes.length;
                                        return Dialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Header
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 20, vertical: 16),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    borderRadius: const BorderRadius.vertical(
                                                        top: Radius.circular(16)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.class_outlined,
                                                          color: Colors.red, size: 20),
                                                      const SizedBox(width: 8),
                                                      const Text(
                                                        "Select Classes",
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 16),
                                                      ),
                                                      const Spacer(),
                                                      if (tempSelected.isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                              horizontal: 10, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red,
                                                            borderRadius: BorderRadius.circular(999),
                                                          ),
                                                          child: Text(
                                                            '${tempSelected.length}',
                                                            style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w600),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),

                                                // Select All
                                                CheckboxListTile(
                                                  activeColor: Colors.red,
                                                  value: isAllSelected,
                                                  title: const Text("Select All",
                                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                                  onChanged: (value) {
                                                    setDialogState(() {
                                                      tempSelected = value == true
                                                          ? classes.map<int>((e) => e['id'] as int).toList()
                                                          : [];
                                                    });
                                                  },
                                                ),
                                                const Divider(height: 0),

                                                // List
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxHeight: 300),
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount: classes.length,
                                                    itemBuilder: (context, index) {
                                                      final item = classes[index];
                                                      final id = item['id'] as int;
                                                      final isSelected = tempSelected.contains(id);
                                                      return CheckboxListTile(
                                                        activeColor: Colors.red,
                                                        value: isSelected,
                                                        title: Text(
                                                          '${item["academic_class"]["title"]} '
                                                              '(${item["section"]["title"]})',
                                                          style: const TextStyle(fontSize: 14),
                                                        ),
                                                        onChanged: (value) {
                                                          setDialogState(() {
                                                            value == true
                                                                ? tempSelected.add(id)
                                                                : tempSelected.remove(id);
                                                          });
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),

                                                // Footer buttons
                                                const Divider(height: 0),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 16, vertical: 12),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: OutlinedButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          style: OutlinedButton.styleFrom(
                                                            side: const BorderSide(color: Colors.grey),
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(10)),
                                                          ),
                                                          child: const Text("Cancel",
                                                              style: TextStyle(color: Colors.grey)),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.red,
                                                            foregroundColor: Colors.white,
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(10)),
                                                          ),
                                                          onPressed: () =>
                                                              Navigator.pop(context, tempSelected),
                                                          child: const Text("Apply"),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );

                                if (result != null) {
                                  setState(() {
                                    selectedClasses = result;
                                    selectedStudents.clear();
                                    selectAllStudents = false;
                                  });
                                  fetchAssignmentsData(resetPage: true);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedClasses.isEmpty
                                        ? Colors.grey.shade300
                                        : Colors.red.shade300,
                                    width: selectedClasses.isEmpty ? 0.5 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.08),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  children: [
                                    const Icon(Icons.school_outlined, color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedClasses.isEmpty
                                            ? "Select Class"
                                            : "${selectedClasses.length} Class${selectedClasses.length > 1 ? 'es' : ''} Selected",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: selectedClasses.isEmpty
                                              ? Colors.grey.shade400
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (selectedClasses.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '${selectedClasses.length}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    const Icon(Icons.keyboard_arrow_down_rounded,
                                        color: Colors.red, size: 22),
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
                      // Checkbox(
                      //   value: _tabController.index == 0
                      //       ? selectAllTeachers
                      //       : selectAllStudents,
                      //   onChanged: (value) => _toggleSelectAll(),
                      //   activeColor: AppColors.primary,
                      // ),

                      Checkbox(
                        value: _tabController.index == 0
                            ? selectAllTeachers
                            : selectedStudents.length == filteredMessages2.length && filteredMessages2.isNotEmpty,
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
                  itemCount: filteredMessages2.length +
                      (_isLoadingMoreStudents ? 1 : 0),
                  itemBuilder: (context, index) {
                    // ─── Bottom loader ───
                    if (index == filteredMessages2.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            )),
                      );
                    }

                    final assignment = filteredMessages2[index];

                    // ✅ FIX: Sirf Set check karo — selectAllStudents || hata diya
                    final isSelected = selectedStudents.contains(
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
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.sp, vertical: 15.sp),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // ✅ important
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file, color: AppColors2.primary),
                      onPressed: _pickFile,
                    ),

                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        constraints: BoxConstraints(
                          maxHeight: 200.sp, // ✅ max height limit
                        ),
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
                          crossAxisAlignment: CrossAxisAlignment.end, // ✅ important
                          children: [
                            Expanded(
                              child: TextField(
                                controller: messageController,
                                minLines: 1, // ✅ start with 1 line
                                maxLines: null, // ✅ auto expand (IMPORTANT)
                                keyboardType: TextInputType.multiline,
                                textCapitalization: TextCapitalization.sentences,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14.sp,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // ✅ Top Right Fixed Button
                    Padding(
                      padding: const EdgeInsets.only(top: 4), // adjust if needed
                      child: CircleAvatar(
                        backgroundColor: AppColors2.primary,
                        child: IconButton(
                          icon: isSending
                              ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Icon(Icons.send, color: Colors.white),
                          onPressed: isSending ? null : _sendMessage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
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