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
        ApiRoutes.getTeacherAllStudents);

    final response = await http.get(url, headers: {
      "Authorization": "Bearer $token",
      "Accept": "application/json",
    });

    final data = jsonDecode(response.body);

    classes = data["data"]["classes"];
    selectedClassId=data["data"]["classes"][0]['class_id'];
    selectedSectionId=data["data"]["classes"][0]['section_id'];
    loadStudents();

    setState(() {
      loading = false;
      sections = [];
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
        "${ApiRoutes.getTeacherAllStudents1}?class=$selectedClassId&section=$selectedSectionId");

    final response = await http.get(url, headers: {
      "Authorization": "Bearer $token",
      "Accept": "application/json",
    });

    final data = jsonDecode(response.body);

    students = data["data"]["students"];
    filteredStudents = students;
    print('examReportData $students');


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
      } else if (sortBy == "adm_no") {
        return int.parse(a["adm_no"].toString())
            .compareTo(int.parse(b["adm_no"].toString()));
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
          loading?SizedBox(
            height: MediaQuery.of(context).size.height*0.5,
              child:  const Center(child: CupertinoActivityIndicator(
                radius: 20,
                color: Colors.black54,
              ))):
          Expanded(
            child: Column(
              children: [
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
                                selectedClassId = item["class_id"];
                                selectedSectionId = item["section_id"];
                              });
                              loadStudents();
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
                                '${item["title"]}-${item["section_title"]}',
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

                // const SizedBox(height: 0),


                // Divider(
                //   height: 2.sp,
                //   color: AppColors2.primary,
                // ),
                // if (selectedSectionId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        infoBox(Icons.people, "Total Students", "${filteredStudents.length}"),
                        infoBox(Icons.boy, "Boy(s)", "$boys"),
                        infoBox(Icons.girl, "Girl(s)", "${filteredStudents.length}"),
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
                      ? const  Center(child: CupertinoActivityIndicator(
                    radius: 20,
                    color: Colors.black54,
                  ))
                      : filteredStudents.isEmpty
                      ? const Center(child: Text("No students found"))
                      : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      itemCount: filteredStudents.length,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1,
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
                                  return  StudentAttendanceScreen(id:   stu["stu_id"],);
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

                                Container(
                                  width: 90.sp,
                                  height: 90.sp,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors2.primary, width: 3),
                                  ),
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: stu["photo"] ??
                                          "https://cdn-icons-png.flaticon.com/512/149/149071.png",

                                      fit: BoxFit.cover,

                                      // 🔥 FAST LOAD Placeholder
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.grey,
                                            size: 35,
                                          ),
                                        ),
                                      ),

                                      // ❌ Error Image
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: Icon(
                                            Icons.error,
                                            color: Colors.red,
                                            size: 35,
                                          ),
                                        ),
                                      ),
                                    ),
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
