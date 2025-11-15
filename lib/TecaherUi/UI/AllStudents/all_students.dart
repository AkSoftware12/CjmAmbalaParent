import 'package:avi/TecaherUi/UI/AllStudents/student_profile.dart';
import 'package:avi/constants.dart';
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

  bool loading = true;
  bool studentsLoading = false;

  List classes = [];
  List sections = [];
  List students = [];
  List filteredStudents = [];

  int? selectedClassId;
  int? selectedSectionId;

  String searchQuery = "";
  String sortBy = "roll";

  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    searchCtrl.addListener(() {
      setState(() {}); // To refresh clear button visibility
    });
    loadInitial();
  }

  // 1️⃣ Load classes
  Future<void> loadInitial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('teachertoken');

    final url = Uri.parse(
        "https://softcjm.cjmambala.co.in/api/teacher-student-atttendance?class=1&section=1");

    final response = await http.get(url, headers: {
      "Authorization": "Bearer $token",
      "Accept": "application/json",
    });

    final data = jsonDecode(response.body);

    classes = data["data"]["classes"];

    setState(() {
      loading = false;
      sections = [];
      students = [];
      filteredStudents = [];
    });
  }

  // 2️⃣ Load sections after class selection
  Future<void> loadSections() async {
    if (selectedClassId == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('teachertoken');

    final url = Uri.parse(
        "https://softcjm.cjmambala.co.in/api/teacher-student-atttendance?class=$selectedClassId&section=1");

    final response = await http.get(url, headers: {
      "Authorization": "Bearer $token",
      "Accept": "application/json",
    });

    final data = jsonDecode(response.body);

    sections = data["data"]["sections"];

    setState(() {
      selectedSectionId = null;
      students = [];
      filteredStudents = [];
    });
  }

  // 3️⃣ Load actual students
  Future<void> loadStudents() async {
    if (selectedClassId == null || selectedSectionId == null) return;

    setState(() => studentsLoading = true);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('teachertoken');

    final url = Uri.parse(
        "https://softcjm.cjmambala.co.in/api/teacher-student-atttendance?class=$selectedClassId&section=$selectedSectionId");

    final response = await http.get(url, headers: {
      "Authorization": "Bearer $token",
      "Accept": "application/json",
    });

    final data = jsonDecode(response.body);

    students = data["data"]["students"];
    filteredStudents = students;

    setState(() => studentsLoading = false);
  }

  // 🔍 Searching
  void filterSearch(String query) {
    searchQuery = query;

    if (query.isEmpty) {
      setState(() => filteredStudents = students);
      return;
    }

    String q = query.toLowerCase();

    setState(() {
      filteredStudents = students.where((stu) {
        String name = stu["student_name"]?.toString().toLowerCase() ?? "";
        String roll = stu["roll_no"]?.toString().toLowerCase() ?? "";
        String adm = stu["adm_no"]?.toString().toLowerCase() ?? "";

        return name.contains(q) || roll.contains(q) || adm.contains(q);
      }).toList();
    });
  }


  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Gender count
    int boys = filteredStudents
        .where((x) => x["gender"]?.toLowerCase() == "male")
        .length;

    int girls = filteredStudents
        .where((x) => x["gender"]?.toLowerCase() == "female")
        .length;

    // Sorting logic
    filteredStudents.sort((a, b) {
      if (sortBy == "roll") {
        return int.parse(a["roll_no"].toString())
            .compareTo(int.parse(b["roll_no"].toString()));
      } else if (sortBy == "admission") {
        return int.parse(a["admission_no"].toString())
            .compareTo(int.parse(b["admission_no"].toString()));
      } else {
        return a["student_name"].compareTo(b["student_name"]);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,

      // ---------------- Green Header ----------------

      body: Column(
        children: [

          Padding(
            padding: EdgeInsets.only(top: 40.sp),
            child: Container(
              height: 50.sp,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors2.primary,
              child: Row(
                children: [
                  // BACK BUTTON
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child:  Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  ),


                  // TITLE TEXT
                  Expanded(
                    child:  Center(
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

          // ---------------- TOP TABS ----------------
          if (classes.isNotEmpty)
            Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.only(bottom: 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: classes.asMap().entries.map((map) {
                    int index = map.key;
                    var item = map.value;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedTab = index;
                          selectedClassId = item["id"];
                        });
                        loadSections();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        margin: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: selectedTab == index
                                  ? AppColors2.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          item["title"],
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: selectedTab == index
                                ? FontWeight.bold
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          const SizedBox(height: 12),
          Divider(
            height: 1.sp,
            color: Colors.grey,
          ),
          // ---------------- Sections Dropdown ----------------
          const SizedBox(height: 3),

          Row(
            children: [
              rowTitle("Select Section"),
            ],
          ),
          const SizedBox(height: 3),

          dropdownBox(
            child: DropdownButtonHideUnderline(
              child: DropdownButton(
                hint: const Text("Select Section"),
                value: selectedSectionId,
                isExpanded: true,
                items: sections.map<DropdownMenuItem<int>>((s) {
                  return DropdownMenuItem(
                    value: s["section_id"],
                    child: Text(s["section_title"]),
                  );
                }).toList(),
                onChanged: selectedClassId == null
                    ? null
                    : (val) {
                  setState(() => selectedSectionId = val as int?);
                  loadStudents();
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ---------------- STUDENT COUNTS ROW ----------------

          Divider(
            height: 1.sp,
            color: Colors.grey,
          ),
          if (selectedSectionId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  infoBox(Icons.people, "Total Students", "${filteredStudents.length}"),
                  infoBox(Icons.boy, "Boy(s)", "$boys"),
                  infoBox(Icons.girl, "Girl(s)", "$girls"),
                ],
              ),
            ),
          Divider(
            height: 1.sp,
            color: Colors.grey,
          ),
          // const SizedBox(height: 10),

          // ---------------- SORT BUTTONS ----------------
          if (selectedSectionId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 10),
              child: Row(
                children: [
                  sortButton("Roll No", "roll"),
                  const SizedBox(width: 8),
                  sortButton("Admission No", "adm_no"),
                  const SizedBox(width: 8),
                  sortButton("Name", "name"),
                ],
              ),
            ),
          Divider(
            height: 1.sp,
            color: Colors.grey,
          ),
          // const SizedBox(height: 10),

          // ---------------- GRID VIEW ----------------
          Expanded(
            child: studentsLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                ? const Center(child: Text("No students found"))
                : GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                itemCount: filteredStudents.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  // crossAxisSpacing: 10,
                  // mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  var stu = filteredStudents[index];

                  return GestureDetector(
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return  StudentAttendanceScreen();
                          },
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border:
                        Border.all(color: AppColors2.primary, width: 1),
                        // Border(right: BorderSide.none,top: BorderSide(color: AppColors2.primary,width: 1.sp),left: BorderSide(color: AppColors2.primary,width: 1.sp))
                        // borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),

                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: NetworkImage(
                              stu["photo"] ??
                                  "https://cdn-icons-png.flaticon.com/512/149/149071.png",
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            stu["student_name"],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),

                          const SizedBox(height: 6),

                          Text("Admission No.: ${stu['adm_no']}"),
                          Text("Roll No : ${stu['roll_no']}"),
                        ],
                      ),
                    ),
                  );
                }),
          ),

          // ---------------- SEARCH BAR (BOTTOM) ----------------
          Padding(
            padding: EdgeInsets.only(bottom: 18.sp),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors2.primary,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.black54),

                    SizedBox(width: 10),

                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Search by Name, Roll No...",
                        ),
                        onChanged: filterSearch,
                      ),
                    ),

                    // ❌ CLEAR BUTTON (only show when text is typed)
                    if (searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          searchCtrl.clear();
                          filterSearch("");   // reset list
                        },
                        child: const Icon(Icons.close, color: Colors.black45),
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

  // ---------------- UI Widgets ----------------
  Widget rowTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 4),
      child: Text(title,
          style:
          const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
    );
  }

  Widget dropdownBox({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(1, 2)),
          ],
        ),
        child: child,
      ),
    );
  }

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
            color: active ?AppColors2.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/az.png',height: 18.sp,width: 15.sp,color:  active ?Colors.white : Colors.black,),
                SizedBox(
                  width: 5.sp,
                ),
                Text(label,
                    style: TextStyle(
                        color: active ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
