import 'package:avi/TecaherUi/UI/AllStudents/student_profile.dart';
import 'package:avi/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AllStudents extends StatefulWidget {
  const AllStudents({super.key});

  @override
  State<AllStudents> createState() => _AllStudentsState();
}

class _AllStudentsState extends State<AllStudents> {
  TextEditingController searchCtrl = TextEditingController();

  // ✅ Controllers for synced scrolling
  final PageController _pageController = PageController();
  final ScrollController _tabScrollController = ScrollController();

  // ✅ GlobalKey list — har tab ka exact size/position measure karne ke liye
  List<GlobalKey> _tabKeys = [];

  bool loading = true;
  bool studentsLoading = false;

  List classes = [];

  // ✅ Map to store students per class tab
  Map<int, List> studentsMap = {};

  int selectedTab = 0;
  String sortBy = "roll";
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    searchCtrl.addListener(() {
      setState(() {});
    });
    loadInitial();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabScrollController.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  // ─── Load classes ────────────────────────────────────────────
  Future<void> loadInitial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('teachertoken');

    final url = Uri.parse(ApiRoutes.getTeacherAllStudents);
    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
    );

    final data = jsonDecode(response.body);
    final List classList = data["data"]?["classes"] ?? [];

    setState(() {
      loading = false;
      classes = classList;
      // ✅ Har class ke liye ek GlobalKey banao
      _tabKeys = List.generate(classList.length, (_) => GlobalKey());
    });

    if (classes.isNotEmpty) {
      await loadStudentsForTab(0);
    }
  }

  // ─── Load students for a specific tab index ──────────────────
  Future<void> loadStudentsForTab(int tabIndex) async {
    // Already loaded → skip API call
    if (studentsMap.containsKey(tabIndex)) return;

    final classItem = classes[tabIndex];
    final int classSectionId = classItem["class_section_id"];

    setState(() => studentsLoading = true);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('teachertoken');

    final url = Uri.parse(
      "${ApiRoutes.getTeacherAllStudents1}?class_section_id=$classSectionId",
    );

    final response = await http.get(
      url,
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
    );

    final data = jsonDecode(response.body);
    final List fetchedStudents = data["data"]["students"] ?? [];

    setState(() {
      studentsMap[tabIndex] = fetchedStudents;
      studentsLoading = false;
    });
  }

  // ─── Get current tab's filtered students ─────────────────────
  List get currentStudents {
    final list = studentsMap[selectedTab] ?? [];
    if (searchQuery.isEmpty) return list;

    final q = searchQuery.toLowerCase();
    return list.where((stu) {
      String name = stu['student']["student_name"]?.toString().toLowerCase() ?? "";
      String roll = stu['student']["roll_no"]?.toString().toLowerCase() ?? "";
      String adm  = stu['student']["adm_no"]?.toString().toLowerCase() ?? "";
      return name.contains(q) || roll.contains(q) || adm.contains(q);
    }).toList();
  }

  // ─── Selected tab ko screen ke CENTER mein scroll karo ──────
  void _scrollTabIntoView(int index) {
    if (_tabKeys.isEmpty || index >= _tabKeys.length) return;

    final key = _tabKeys[index];
    final keyContext = key.currentContext;
    if (keyContext == null) return;

    // Tab widget ka RenderBox lao
    final RenderBox tabBox = keyContext.findRenderObject() as RenderBox;

    // Tab bar ScrollController ka RenderBox lao
    final RenderBox? scrollBox =
    _tabScrollController.hasClients
        ? (_tabScrollController.position.context.storageContext
        .findRenderObject() as RenderBox?)
        : null;

    // Tab ki left position (scroll ke andar)
    final tabOffset = tabBox.localToGlobal(Offset.zero).dx;
    final tabWidth = tabBox.size.width;

    // Screen width
    final screenWidth = MediaQuery.of(context).size.width;

    // Current scroll offset
    final currentScroll = _tabScrollController.offset;

    // Tab center ko screen center pe lane ke liye offset calculate karo
    final targetScroll =
        currentScroll + tabOffset - (screenWidth / 2) + (tabWidth / 2);

    _tabScrollController.animateTo(
      targetScroll.clamp(0.0, _tabScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ─── On tab tap ──────────────────────────────────────────────
  void onTabTap(int index) async {
    setState(() {
      selectedTab = index;
      searchQuery = "";
      searchCtrl.clear();
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    // ✅ Frame render hone ke baad center scroll
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTabIntoView(index));
    await loadStudentsForTab(index);
  }

  void onPageChanged(int index) async {
    setState(() {
      selectedTab = index;
      searchQuery = "";
      searchCtrl.clear();
    });
    // ✅ Frame render hone ke baad center scroll
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTabIntoView(index));
    await loadStudentsForTab(index);
  }

  // ─── Search ──────────────────────────────────────────────────
  void filterSearch(String query) {
    setState(() => searchQuery = query);
  }

  // ─── Sort ────────────────────────────────────────────────────
  List getSorted(List list) {
    final sorted = List.from(list);

    sorted.sort((a, b) {
      if (sortBy == "roll") {
        int rollA = int.tryParse(a['student']?["roll_no"]?.toString() ?? "") ?? 0;
        int rollB = int.tryParse(b['student']?["roll_no"]?.toString() ?? "") ?? 0;
        return rollA.compareTo(rollB);

      } else if (sortBy == "adm_no") {
        int admA = int.tryParse(a['student']?["adm_no"]?.toString() ?? "") ?? 0;
        int admB = int.tryParse(b['student']?["adm_no"]?.toString() ?? "") ?? 0;
        return admA.compareTo(admB);

      } else {
        String nameA = a['student']?["student_name"]?.toString() ?? "";
        String nameB = b['student']?["student_name"]?.toString() ?? "";
        return nameA.compareTo(nameB);
      }
    });

    return sorted;
  }

  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Header ──
          Padding(
            padding: EdgeInsets.only(top: 40.sp),
            child: Container(
              height: 50.sp,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors2.primary,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 22.sp),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Student List",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──
          loading
              ? SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const Center(
              child: CupertinoActivityIndicator(radius: 20, color: Colors.black54),
            ),
          )
              : classes.isEmpty
              ? SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.class_outlined, size: 90, color: Colors.blue),
                  SizedBox(height: 16),
                  Text(
                    "No Class Available",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          )
              : Expanded(
            child: Column(
              children: [
                // ── Class Tabs ──
                Container(
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: SingleChildScrollView(
                    controller: _tabScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: classes.asMap().entries.map((entry) {
                        int index = entry.key;
                        var item = entry.value;
                        bool isActive = selectedTab == index;
                        return GestureDetector(
                          onTap: () => onTabTap(index),
                          child: Container(
                            key: _tabKeys[index], // ✅ GlobalKey assign
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            margin: const EdgeInsets.only(left: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isActive
                                      ? AppColors2.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              '${item["title"]}-${item["section_title"]}',
                              style: TextStyle(
                                color: isActive
                                    ? AppColors2.primary
                                    : Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // ── PageView for students ──
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: classes.length,
                    onPageChanged: onPageChanged, // 👈 swipe se tab change
                    itemBuilder: (context, pageIndex) {
                      // Show loader for current swiped page while loading
                      if (!studentsMap.containsKey(pageIndex)) {
                        return const Center(
                          child: CupertinoActivityIndicator(
                            radius: 20,
                            color: Colors.black54,
                          ),
                        );
                      }

                      final pageStudents = getSorted(
                        pageIndex == selectedTab
                            ? currentStudents
                            : studentsMap[pageIndex] ?? [],
                      );

                      final boys = pageStudents
                          .where((x) =>
                      x["gender"]?.toLowerCase() == "male")
                          .length;
                      final girls = pageStudents
                          .where((x) =>
                      x["gender"]?.toLowerCase() == "female")
                          .length;

                      return Column(
                        children: [
                          // ── Stats Row ──
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                infoBox(Icons.people, "Total",
                                    "${pageStudents.length}"),
                                // infoBox(Icons.boy, "Boy(s)", "$boys"),
                                // infoBox(
                                //     Icons.girl, "Girl(s)", "$girls"),
                              ],
                            ),
                          ),
                          Divider(height: 1.sp, color: Colors.grey),

                          // ── Sort Buttons ──
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                sortButton("Roll No", "roll"),
                                const SizedBox(width: 8),
                                sortButton("Adm No", "adm_no"),
                                const SizedBox(width: 8),
                                sortButton("Name", "student_name"),
                              ],
                            ),
                          ),
                          Divider(height: 1.sp, color: Colors.grey),

                          // ── Grid ──
                          Expanded(
                            child: studentsLoading &&
                                pageIndex == selectedTab
                                ? const Center(
                                child: CupertinoActivityIndicator(
                                    radius: 20,
                                    color: Colors.black54))
                                : pageStudents.isEmpty
                                ? const Center(
                                child: Text(
                                    "No students found"))
                                : GridView.builder(
                              padding: EdgeInsets.zero,
                              itemCount:
                              pageStudents.length,
                              gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1,
                              ),
                              itemBuilder:
                                  (context, index) {
                                var stu =
                                pageStudents[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            StudentAttendanceScreen(
                                              id: stu['student']["id"],
                                              studentId: stu['student']["student_id"].toString(),
                                            ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors2
                                            .primary,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        const SizedBox(
                                            height: 10),
                                        Container(
                                          width: 90.sp,
                                          height: 90.sp,
                                          decoration:
                                          BoxDecoration(
                                            shape: BoxShape
                                                .circle,
                                            border:
                                            Border.all(
                                              color: AppColors2
                                                  .primary,
                                              width: 3,
                                            ),
                                          ),
                                          child: ClipOval(
                                            child:
                                            CachedNetworkImage(
                                              imageUrl: stu[
                                              'student']
                                              [
                                              "picture_data"] ??
                                                  "https://cdn-icons-png.flaticon.com/512/149/149071.png",
                                              fit: BoxFit
                                                  .cover,
                                              placeholder: (context,
                                                  url) =>
                                                  Container(
                                                    color: Colors
                                                        .grey
                                                        .shade200,
                                                    child:
                                                    const Center(
                                                      child: Icon(
                                                          Icons
                                                              .person,
                                                          color: Colors
                                                              .grey,
                                                          size:
                                                          35),
                                                    ),
                                                  ),
                                              errorWidget: (context,
                                                  url,
                                                  error) =>
                                                  Container(
                                                    color: Colors
                                                        .grey
                                                        .shade200,
                                                    child:
                                                    const Center(
                                                      child: Icon(
                                                          Icons
                                                              .error,
                                                          color: Colors
                                                              .red,
                                                          size:
                                                          35),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 10),
                                        Text(
                                          stu['student']["student_name"].toString(),
                                          style: const TextStyle(
                                              fontWeight:
                                              FontWeight
                                                  .bold,
                                              fontSize: 15),
                                          textAlign:
                                          TextAlign
                                              .center,
                                          maxLines: 1,
                                          overflow:
                                          TextOverflow
                                              .ellipsis,
                                        ),
                                        const SizedBox(
                                            height: 6),
                                        Text(
                                            "Adm: ${stu['student']['adm_no']??'N/A'}"),
                                        Text(
                                            "Roll: ${stu['student']['roll_no']??'N/A'}"),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // ── Search Bar ──
                          Padding(
                            padding: EdgeInsets.only(bottom: 18.sp),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              color: AppColors2.primary,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                  BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search,
                                        color: Colors.black54),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: searchCtrl,
                                        decoration:
                                        const InputDecoration(
                                          border: InputBorder.none,
                                          hintText:
                                          "Search by Name, Roll No...",
                                        ),
                                        onChanged: filterSearch,
                                      ),
                                    ),
                                    if (searchCtrl.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          searchCtrl.clear();
                                          filterSearch("");
                                        },
                                        child: const Icon(
                                            Icons.close,
                                            color: Colors.black45),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helper Widgets ──────────────────────────────────────────
  Widget infoBox(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black87),
        const SizedBox(width: 5),
        Text("$title $value", style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget sortButton(String label, String type) {
    bool active = sortBy == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => sortBy = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors2.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/az.png',
                  height: 18.sp,
                  width: 15.sp,
                  color: active ? Colors.white : Colors.black,
                ),
                SizedBox(width: 5.sp),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}