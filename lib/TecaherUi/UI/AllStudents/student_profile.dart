import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:lottie/lottie.dart';
import 'package:avi/HexColorCode/HexColor.dart';
import 'package:avi/constants.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class StudentAttendanceScreen extends StatefulWidget {
  final int id;
  final int? classSectionId;
  final int? enrollId;
  final int? termId;
  const StudentAttendanceScreen({super.key, required this.id, this.classSectionId, this.enrollId, this.termId});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {

  final ScrollController tabScrollController = ScrollController();
  List<GlobalKey> tabKeys = List.generate(5, (_) => GlobalKey());
  bool isLoading = true;

  // PAGE CONTROLLER
  final PageController _pageController = PageController();
  int currentPage = 0;
  Map<String, dynamic>? studentData;
  Map<String, dynamic>? examReportData;
  Map<String, dynamic>? attendanceData;
  List fees = [];



  @override
  void initState() {
    super.initState();
    fetchProfileData(widget.id);
  }


  Future<void> fetchProfileData(int id) async {
    final response = await http.get(
      Uri.parse('${ApiRoutes.getTeacherStudentsProfile}$id'),
      headers: {'Authorization': 'Bearer ${''}'},
    );

    if (!mounted) return; // ✅ Prevent running code after dispose

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          studentData = data['data'];
          attendanceData = data['attendance_summary'];
          fees = data['fees'];


           examDataApi(studentData?['student_enrolls'][0]['class_section_id'], studentData?['student_enrolls'][0]['id'],1);


          print('get Profile $studentData');
          print('fee Profile $fees');
          isLoading = false;
        });
      }
    } else {
    }
  }

  Future<void> examDataApi(int classSectionId, int enrollId, int termId) async {
    final response = await http.get(
      Uri.parse('${ApiRoutes.baseExamUrl}student-exam?class_section_id=$classSectionId&enroll_id=$enrollId&term_id=$termId',
      ),
      headers: {'Authorization': 'Bearer ${''}'},
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      if (mounted) {
        setState(() {
          examReportData = data;   // <-- FULL JSON MAP
          isLoading = false;

          print("FULL EXAM REPORT: $examReportData");
        });
      }
    }
  }

  Map<String, double> calculateChartData(Map<String, dynamic> summary) {
    double present = 0;
    double absent = 0;
    double leave = 0;
    double holiday = 0;

    summary.forEach((key, v) {
      present += (v["present"] ?? 0).toDouble();
      absent += (v["absent"] ?? 0).toDouble();
      leave += (v["leave"] ?? 0).toDouble();
      holiday += (v["holiday"] ?? 0).toDouble();
    });

    // TOTAL DAYS
    double total = present + absent + leave + holiday;

    if (total == 0) {
      return {
        "present": 0,
        "absent": 0,
        "leave": 0,
        "holiday": 0,
      };
    }

    return {
      "present": (present / total) * 100,
      "absent": (absent / total) * 100,
      "leave": (leave / total) * 100,
      "holiday": (holiday / total) * 100,
    };
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body:

      Column(
        children: [
          SizedBox(height: 40.sp),

          // ---------------- TOP APP BAR ----------------
          Container(
            padding: const EdgeInsets.only(
                top: 20, left: 12, right: 12, bottom: 16),
            color: AppColors2.primary,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                      Icons.arrow_back, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Text(
                  "Students Profile",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                )
              ],
            ),
          ),



          // ---------------- PAGEVIEW CONTENT ----------------
          isLoading ?SizedBox(
            height: MediaQuery.of(context).size.height*0.8,
            child: const Center(child: CupertinoActivityIndicator(
              radius: 20,
              color: Colors.redAccent,
            )),
          ):
          Expanded(
            child: Column(
              children: [
                // ---------------- STUDENT INFO ----------------
                Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(10.sp),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return FullScreenImageViewer(
                                imageUrl: studentData?['photo'] ?? '',
                              );
                            },
                          );
                        },
                        child: Container(
                          height: 90.sp,
                          width: 90.sp,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: HexColor('#e92728'),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: studentData?['photo'] ?? '',
                              // fit: BoxFit.fill,

                              // ---------- FAST PLACEHOLDER ----------
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade300,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),

                              // ---------- ERROR IMAGE ----------
                              errorWidget: (context, url, error) => Image.asset(
                                AppAssets.cjmlogo,
                                fit: BoxFit.cover,
                              ),

                              // ---------- FADE-IN (looks fast) ----------
                              fadeInDuration: const Duration(milliseconds: 300),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                                "${ studentData?['student_name']??''}",
                                style: GoogleFonts.poppins(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            Text("Class: ",
                                style: GoogleFonts.poppins(color: Colors.grey.shade700,fontWeight: FontWeight.bold)),
                            Text(
                                "${ studentData?['class_name']??''}-${studentData?['sectionname']['title']??''}",
                                style: GoogleFonts.poppins(color: Colors.black,fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            Text("Admission No.: ",
                                style: GoogleFonts.poppins(color: Colors.grey.shade700,fontWeight: FontWeight.bold)),
                            Text(
                                "${ studentData?['adm_no']??''}",
                                style: GoogleFonts.poppins(color: Colors.black,fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            Text("DOJ: ",
                                style: GoogleFonts.poppins(color: Colors.grey.shade700,fontWeight: FontWeight.bold)),
                            Text(
                                "${ studentData?['date_of_joining']??''}",
                                style: GoogleFonts.poppins(color: Colors.black,fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),

                const Divider(thickness: 1.5, color: Colors.grey),
                Expanded(
                  child: Column(
                    children: [
                      // 🔥 PAGE VIEW HERE 🔥
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => currentPage = index);
                            // ⭐ PAGEVIEW SWIPE par bhi auto-center tab
                            Scrollable.ensureVisible(
                              tabKeys[index].currentContext!,
                              duration: const Duration(milliseconds: 300),
                              alignment: 0.5,
                              curve: Curves.easeInOut,
                            );
                          },
                          children: [
                            studentProfileUI(),
                            attendancePage(),
                            ExamReportScreen(data:examReportData,),
                            FeePage(fees: fees),
                            libraryPage(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ---------------- BOTTOM NAVIGATION ----------------
                Padding(
                  padding:  EdgeInsets.only(bottom: 10.sp),
                  child: Container(
                    height: 55,
                    color: Colors.grey.shade200,
                    child: SingleChildScrollView(
                      controller: tabScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          bottomTab("Personal Details", 0),
                          bottomTab("Attendance", 1),
                          bottomTab("Academic Performance", 2),
                          bottomTab("Fee Details", 3),
                          bottomTab("Library", 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

            ),
          ),
        ]

      ),
    );
  }

  Widget bottomTab(String title, int index) {
    bool active = currentPage == index;

    return Container(
      key: tabKeys[index],  // ⭐ IMPORTANT !!
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => currentPage = index);

          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );

          // ⭐ Selected tab ko hamesha visible rakho
          Scrollable.ensureVisible(
            tabKeys[index].currentContext!,
            duration: Duration(milliseconds: 300),
            alignment: 0.5, // ⭐ Center me lane ke liye
            curve: Curves.easeInOut,
          );
        },
        child: Text(
          title,
          style: GoogleFonts.poppins(
            color: active ? Colors.red : Colors.black,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }



  Widget studentProfileUI() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          // color: Colors.grey.shade100,
        ),
        child: Column(
          children: [
            // ------------------ BIG CARD ------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
              ),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -----------------------------------------------------
                  // LEFT SIDE COLUMN
                  // -----------------------------------------------------
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        infoItem(Icons.person, "Gender", studentData?['gender'] ?? ''),
                        infoItem(Icons.cake, "Date of Birth", studentData?['dob'] ?? ''),
                        infoItem(Icons.confirmation_number, "Roll No", studentData?['roll_no'] ?? ''),
                        infoItem(Icons.home_work, "House", studentData?['house'] ?? 'N/A'),
                        infoItem(Icons.directions_bus, "Transport", studentData?['transport'] ?? 'N/A'),
                        infoItem(Icons.bloodtype, "Blood Group", studentData?['blood_group'] ?? 'N/A'),
                        infoItem(Icons.category, "Category", studentData?['social_category'] ?? 'N/A'),
                        infoItem(Icons.people, "Caste", studentData?['social_category'] ?? 'N/A'),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // -----------------------------------------------------
                  // RIGHT SIDE COLUMN
                  // -----------------------------------------------------
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        infoItem(Icons.credit_card, "Aadhaar Number", studentData?['adharcard_no'] ?? 'N/A'),
                        infoItem(Icons.mosque, "Religion", studentData?['studentreligion']?['title'] ?? 'N/A'),
                        infoItem(Icons.flag, "Nationality", studentData?['nationality'] ?? 'N/A'),

                        const SizedBox(height: 12),
                        infoItem(Icons.location_on, "Address",  studentData?['address'] ?? 'N/A',),


                        const SizedBox(height: 14),

                        infoItem(Icons.phone, "Contact No.", studentData?['contact_no'] ?? 'N/A'),
                        infoItem(Icons.email, "Email", studentData?['email'] ?? 'N/A'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// ----------------------------
  /// PREMIUM LABEL + VALUE + ICON
  /// ----------------------------
  Widget infoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent.withOpacity(0.8)),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),

                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- PAGE 1: Attendance --------------------
  Widget attendancePage() {
    if (attendanceData == null) {
      return Center(child: CircularProgressIndicator());
    }

    final Map<String, dynamic> summary = attendanceData!;
    final List months = summary.values.toList();
    final chart = calculateChartData(summary);
    Map<String, double> getTotalSummary(List months) {
      double totalWorking = 0;
      double totalPresent = 0;
      double totalAbsent = 0;
      double totalLeave = 0;
      double totalHoliday = 0;

      for (var m in months) {
        totalWorking += (m["working_days"] ?? 0).toDouble();
        totalPresent += (m["present"] ?? 0).toDouble();
        totalAbsent += (m["absent"] ?? 0).toDouble();
        totalLeave += (m["leave"] ?? 0).toDouble();
        totalHoliday += (m["holiday"] ?? 0).toDouble();
      }

      double percent =
      totalWorking == 0 ? 0 : ((totalPresent / totalWorking) * 100);

      return {
        "working": totalWorking,
        "present": totalPresent,
        "absent": totalAbsent,
        "leave": totalLeave,
        "holiday": totalHoliday,
        "percent": percent,
      };
    }
    final totals = getTotalSummary(months);


    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(0.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // -------------------------------------------------
            //               DONUT CHART + STATS
            // -------------------------------------------------
            Container(
              padding: EdgeInsets.all(10.sp),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  // Donut
                  SizedBox(
                    height: 120.sp,
                    width: 150.sp,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 35,
                        sectionsSpace: 3,
                        sections: [
                          PieChartSectionData(
                              titleStyle:  TextStyle(
                                  color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp
                              ),
                              value: chart["present"],
                              title: "${chart["present"]!.toStringAsFixed(1)} %",
                              color: Colors.green,
                              radius: 45),
                          PieChartSectionData(
                              titleStyle:  TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp
                              ),
                              value: chart["absent"],
                              title: "${chart["absent"]!.toStringAsFixed(1)} %",
                              color: Colors.red,
                              radius: 45),
                          PieChartSectionData(
                              titleStyle:  TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp
                              ),
                              value: chart["leave"],
                              title: "${chart["leave"]!.toStringAsFixed(1)} %",
                              color: Colors.orange,
                              radius: 45),
                          PieChartSectionData(
                              titleStyle:  TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp
                              ),
                              value: chart["holiday"],
                              color: Colors.purple,
                              radius: 45),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: 20),

                  // Stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        statRow("Present", Colors.green, chart["present"].toString()),
                        statRow("Absent", Colors.red, chart["absent"].toString()),
                        statRow("Leave", Colors.orange, chart["leave"].toString()),
                        statRow("Holiday", Colors.purple, chart["holiday"].toString()),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 25),

            // -------------------------------------------------
            //                    TABLE HEADER
            // -------------------------------------------------
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.sp),
              decoration: BoxDecoration(
                // color: Colors.blue.shade50,
                color: AppColors2.primary,
                borderRadius: BorderRadius.circular(0),
              ),
              child: Row(
                children: [
                  tableHeader("Month"),
                  tableHeader("Working Days"),
                  tableHeader("Present"),
                  tableHeader("Absent"),
                  tableHeader("Leave"),
                  tableHeader("Holiday"),
                  // tableHeader("%"),
                ],
              ),
            ),

            SizedBox(height: 10),

            // -------------------------------------------------
            //                    DYNAMIC ROWS
            // -------------------------------------------------
            ...months.map((m) {
              return buildRowDynamic(
                m["month"],
                m["working_days"],
                m["present"],
                m["absent"],
                m["leave"],
                m["holiday"],
                // m["percentage"].toString(),
              );
            }).toList(),

    SizedBox(height: 10),


            buildRowDynamic(
              "TOTAL",
              totals["working"]!.toInt(),
              totals["present"]!.toInt(),
              totals["absent"]!.toInt(),
              totals["leave"]!.toInt(),
              totals["holiday"]!.toInt(),
              // totals["percent"]!.toStringAsFixed(1) + "%",
              isTotal: true,   // EXTRA PARAMETER
            ),

          ],
        ),
      ),
    );
  }
  Widget buildRowDynamic(
      String month,
      int working,
      int present,
      int absent,
      int leave,
      int holiday,
      // String percentage,
      {
        bool isTotal = false,
      }
      ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
          color: isTotal ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(0),
      ),
      child: Row(
        children: [
          tableMonth(month,isTotal),
          tableValue("$working"),
          tableValue("$present"),
          tableValue("$absent"),
          tableValue("$leave"),
          tableValue("$holiday"),
          // tableValue(percentage),
        ],
      ),
    );
  }
  Widget tableValue(String text) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
  Widget tableMonth(String text, bool isTotal,
  ) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: GoogleFonts.poppins(
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
          color:isTotal ? Colors.black : Colors.green,
        ),
      ),
    );
  }
  // -------------------- PAGE 2 --------------------
  Widget performancePage() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

    // ------------- Term Tabs ----------------
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Term-1",
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Text("Collapes All", style: TextStyle(fontSize: 14)),
                    Icon(Icons.keyboard_arrow_up)
                  ],
                )
              ],
            ),
          ),

          // ------------- SUBJECT LIST SCROLL ----------------
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding:  EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    subjectTileAlwaysOpen(
                      title: "ENGLISH",
                      exams: [
                        examItem("Periodic Test 1", 9, 20),
                        examItem("Notebook 1", 8, 10),
                        examItem("Orals 1", 7, 20),
                        examItem("Half Yearly Exam", 45, 50),
                      ],
                    ),
                    subjectTileAlwaysOpen(
                      title: "MATHEMATICS",
                      exams: [
                        examItem("Periodic Test 1", 9, 20),
                        examItem("Notebook 1", 8, 10),
                      ],
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

// -------------------- Helper Widgets --------------------

  Widget subjectTileAlwaysOpen({
    required String title,
    required List<Widget> exams,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AppColors2.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            width: double.infinity,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          // White body part
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.white,
            child: Column(children: exams),
          )
        ],
      ),
    );
  }

  Widget examItem(String exam, int marks, int maxMarks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          "Exam   $exam",
          style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Marks   $marks",
                style: const TextStyle(
                    fontSize: 14, color: Colors.black)),
            Text("Max  $maxMarks",
                style: const TextStyle(
                    fontSize: 14, color: Colors.black45)),
          ],
        ),
        const SizedBox(height: 8),
        Divider(color: Colors.grey.shade300),
      ],
    );
  }




  // -------------------- PAGE 4 --------------------
  Widget libraryPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // -------------------------------------------------------------
            //      LIBRARY TRANSACTION DETAILS BOX
            // -------------------------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors2.primary),
                boxShadow: [
                  BoxShadow(
                    color:AppColors2.primary,
                    blurRadius: 4,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "Library Transaction Details",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ----------- Issued / Returned / Pending Row -------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Column(
                        children: [
                          Text("Issued",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          SizedBox(height: 6),
                          Text("0",
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          Text("Returned",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          SizedBox(height: 6),
                          Text("0",
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          Text("Pending",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          SizedBox(height: 6),
                          Text("0",
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    "View Details",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.green.shade700,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------------------------------------------
            //                LIBRARY FINE DETAILS BOX
            // -------------------------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors2.primary),
                boxShadow: [
                  BoxShadow(
                    color:AppColors2.primary,
                    blurRadius: 4,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "Library Fine Details",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ----------- Dues / Waive Off / Paid / Pending Row ------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Column(
                        children: [
                          Text("Dues",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          SizedBox(height: 6),
                          Text("0.0",
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          Text("Waive off",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          SizedBox(height: 6),
                          Text("0.0",
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                        ],
                      ),
                      Column(
                        children: [
                          Text("Paid",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          SizedBox(height: 6),
                          Text("0.0",
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                      Column(
                        children: [
                          Text("Pending",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey)),
                          SizedBox(height: 6),
                          Text("0.0",
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    "View Fine Details",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.green.shade700,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // workingCurrentlyPage
  Widget workingCurrentlyPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                // height: 40,
                // width: 40,
                child: Lottie.asset(
                  "assets/working.json",  // <-- yaha apna Lottie JSON file daalo
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 10),

              Padding(
                padding:  EdgeInsets.only(left:40.sp,right: 40.sp),
                child: Text(
                  "Work is currently in progress here.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    shadows: [
                      Shadow(
                        blurRadius: 15,
                        color: Colors.blueAccent.withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }
  // =================== Widgets ===================

  Widget statRow(String title, Color color, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            height: 12,
            width: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          SizedBox(width: 8),
          Text(
            "$title: ",
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            '$value %',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget tableHeader(String txt) {
    return Expanded(
      child: Padding(
        padding:  EdgeInsets.only(left: 5.sp),
        child: Center(
          child: SizedBox(
            height: 30.sp,
            child: Text(txt,
                style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 10.sp,color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRow(String month, int working) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(month, maxLines: 1,
              style: GoogleFonts.poppins(color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.sp))),
          SizedBox(
            width: 5.sp,
          ),
          Expanded(child: Text("$working")),
          Expanded(child: Text("$working")),
          Expanded(child: Text("$working")),
          Expanded(child: Text("0")),
          Expanded(child: Text("0")),
          Expanded(child: Text("0")),
          Expanded(child: Text("0")),
        ],
      ),
    );
  }


}



class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.9),
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Fullscreen Zoomable Image
          Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              child:CachedNetworkImage(
                imageUrl: imageUrl ?? '',
                fit: BoxFit.contain,
                height: MediaQuery.of(context).size.height,
                width:  MediaQuery.of(context).size.width,

                // ---------- FAST PLACEHOLDER ----------
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade300,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.redAccent,
                    ),
                  ),
                ),

                // ---------- ERROR IMAGE ----------
                errorWidget: (context, url, error) => Image.asset(
                  AppAssets.cjmlogo,
                  fit: BoxFit.cover,
                ),

                // ---------- FADE-IN (looks fast) ----------
                fadeInDuration: const Duration(milliseconds: 300),
              ),


            ),
          ),

          // Close Button - TOP RIGHT
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class FeePage extends StatelessWidget {
  final List<dynamic> fees;

  FeePage({required this.fees});

  @override
  Widget build(BuildContext context) {
    final parsed = _parseFees(fees);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(5.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

          //  // ================= HEADER =================
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.end,
            //   children: [
            //     _paidButton(),
            //   ],
            // ),
            SizedBox(height: 10),

            // ================= CARD TABLE =================
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 8.sp),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                // boxShadow: [
                //   BoxShadow(
                //       color: Colors.black.withOpacity(0.06),
                //       blurRadius: 12,
                //       offset: Offset(0, 4))
                // ],
              ),
              child: Column(
                children: [
                  _tableHeaderRow(),
                  Divider(),
                  ...parsed["rows"],
                  Divider(),
                  _totalRow(parsed),
                ],
              ),
            ),

            SizedBox(height: 30),

            // ================= PIE CHART =================
            _pieChartCard(parsed),
          ],
        ),
      ),
    );
  }

  // ---------------------- DROPDOWN ----------------------

  // ---------------------- VIEW PAID BUTTON ----------------------
  Widget _paidButton() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff2ecc71), Color(0xff27ae60)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withOpacity(0.25),
              blurRadius: 10,
              offset: Offset(0, 4))
        ],
      ),
      child: Text(
        "View paid transaction",
        style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ---------------------- TABLE HEADER ----------------------
  Widget _tableHeaderRow() {
    return Row(
      children: [
        Expanded(flex: 1, child: _tableHeader("Installment")),
        SizedBox(width: 15.sp,),
        Expanded(child: _tableHeader("Actual")),
        Expanded(child: _tableHeader("Concession")),
        Expanded(child: _tableHeader("Received")),
        Expanded(child: _tableHeader("Due")),
      ],
    );
  }

  Widget _tableHeader(String text) {
    return Center(
      child: Text(text,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 10.sp, color: Colors.grey.shade600)),
    );
  }

  // ---------------------- TOTAL ROW ----------------------
  Widget _totalRow(parsed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
            flex: 1,
            child: Center(
              child: Text("Total Amount",
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            )),
        SizedBox(width: 15.sp,),
        Expanded(child: _bold(parsed["totalActual"])),
        Expanded(child: _bold(parsed["totalConcession"])),
        Expanded(child: _bold(parsed["totalReceived"])),
        Expanded(child: _bold(parsed["totalOutstanding"])),
      ],
    );
  }

  Widget _bold(dynamic v) =>
      Center(
    child: Text(
      v.toString(),
      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),

    ),
  );

  // ---------------------- PIE CHART CARD ----------------------
  Widget _pieChartCard(parsed) {
    return Container(
      padding: EdgeInsets.all(10.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        // boxShadow: [
        //   BoxShadow(
        //       color: Colors.black.withOpacity(0.06),
        //       blurRadius: 12,
        //       offset: Offset(0, 3))
        // ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 160.sp,
            width: 150.sp,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 35,
                sectionsSpace: 2,
                sections: [
                  PieChartSectionData(
                      value: parsed["receivedPercent"],
                      title: '${parsed["receivedPercent"].toStringAsFixed(2)} %',
                      titleStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold
                      ),
                      color: Color(0xff2ecc71),
                      radius: 45),
                  PieChartSectionData(
                      titleStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold
                      ),
                      value: parsed["outstandingPercent"],
                      title: '${parsed["outstandingPercent"].toStringAsFixed(2)} %',
                      color: Color(0xffe74c3c),
                      radius: 45),
                  PieChartSectionData(
                    value: parsed["concessionPercent"],
                    title: '${parsed["concessionPercent"].toStringAsFixed(2)}%',
                    radius: 45,
                    color: Colors.grey.shade400,
                    titleStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),


                ],
              ),
            ),
          ),
          SizedBox(width: 5.sp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legend(Color(0xff2ecc71),
                    "Received (${parsed["receivedPercent"].toStringAsFixed(2)}%)"),
                SizedBox(height: 10),
                _legend(Color(0xffe74c3c),
                    "Outstanding (${parsed["outstandingPercent"].toStringAsFixed(2)}%)"),
                SizedBox(height: 10),
                _legend(Colors.grey.shade400,
                    "Concession (${parsed["concessionPercent"].toStringAsFixed(2)}%)"),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _legend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8),
        Text(text, style: GoogleFonts.poppins(fontSize: 13)),
      ],
    );
  }

  // ------------------ FEES ROW UI ------------------
  Widget _feeRow(String title, String actual, String conc, String rec, String out) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
              flex: 1,
              child: SizedBox(
                // width: 80.sp,
                child: Center(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600,fontSize: 10.sp),
                  ),
                ),
              )),
          SizedBox(
            width: 15.sp,
          ),
          Expanded(child: Center(child: Text(actual))),
          Expanded(child: Center(child: Text(conc))),
          Expanded(
              child: Center(
                child: Text(
                  rec,
                  style: TextStyle(color: Colors.green.shade700),
                ),
              )),
          Expanded(
              child: Center(
                child: Text(
                  out,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              )),
        ],
      ),
    );
  }

  // ----------------- PARSE LOGIC -----------------
  Map<String, dynamic> _parseFees(List<dynamic> fees) {
    double totalActual = 0;
    double totalConcession = 0;
    double totalReceived = 0;
    double totalOutstanding = 0;

    List<Widget> rows = [];

    for (var f in fees) {
      double actual = double.tryParse(f["final_amount"].toString()) ?? 0;
      double concession = double.tryParse(f["concession_amount"].toString()) ?? 0;

      double received = f["pay_status"] == "paid" ? actual - concession : 0;
      double outstanding = f["pay_status"] == "paid" ? 0 : actual - concession;

      totalActual += actual;
      totalConcession += concession;
      totalReceived += received;
      totalOutstanding += outstanding;

      rows.add(_feeRow(
        f["installment"]["title"].toString(),
        actual.toString(),
        concession.toString(),
        received.toString(),
        outstanding.toString(),
      ));
    }

    double total = totalActual == 0 ? 1 : totalActual;

    return {
      "rows": rows,
      "totalActual": totalActual,
      "totalConcession": totalConcession,
      "totalReceived": totalReceived,
      "totalOutstanding": totalOutstanding,
      "receivedPercent": (totalReceived / total) * 100,
      "outstandingPercent": (totalOutstanding / total) * 100,
      "concessionPercent": (totalConcession / total) * 100,
    };
  }
}



class ExamReportScreen extends StatefulWidget {
  final Map<String, dynamic>? data;

  const ExamReportScreen({super.key, required this.data});

  @override
  State<ExamReportScreen> createState() => _ExamReportScreenState();
}

class _ExamReportScreenState extends State<ExamReportScreen> {
  int selectedTerm = 0;

  /// Track each subject individually
  List<bool> subjectExpanded = [];

  @override
  Widget build(BuildContext context) {
    List terms = widget.data?["terms"] ?? [];
    List subjects = terms.isNotEmpty
        ? terms[selectedTerm]["subjects"] ?? []
        : [];

    // Initialize subject expansion state
    if (subjectExpanded.length != subjects.length) {
      subjectExpanded = List.generate(subjects.length, (_) => true);
    }

    return Column(
      children: [
        // ---------------- TERM TABS ----------------
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: List.generate(
              terms.length,
                  (index) {
                bool active = index == selectedTerm;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedTerm = index;
                      subjectExpanded = [];
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // -------- TERM TEXT --------
                        Text(
                          terms[index]["term_name"],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors2.primary : Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 5),

                        // -------- GREEN UNDERLINE (only for selected) --------
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 4,
                          width: active ? 60 : 0,
                          decoration: BoxDecoration(
                            color:  AppColors2.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 5),

        // ---------------- SUBJECT LIST ----------------
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(0),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("",
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),

                  // -------- COLLAPSE / EXPAND ALL ----------
                  InkWell(
                    onTap: () {
                      bool newState =
                      subjectExpanded.any((e) => e == true) ? false : true;

                      setState(() {
                        subjectExpanded =
                            List.generate(subjects.length, (_) => newState);
                      });
                    },
                    child: Row(
                      children: [
                        Text(
                          subjectExpanded.any((e) => e == true)
                              ? "Collapse All"
                              : "Expand All",
                          style: const TextStyle(fontSize: 14),
                        ),
                        Icon(
                          subjectExpanded.any((e) => e == true)
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                      ],
                    ),
                  )
                ],
              ),

              const SizedBox(height: 10),

              // ------------------ CHECK IF ANY SUBJECT HAS EXAMS ------------------
              if (!subjects.any((s) => (s["exams"] ?? []).isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 150),
                  child:  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(50.0),
                          child: SizedBox(
                            // height: 100,
                            // width: 100,
                            child: Lottie.asset(
                              "assets/nodata.json",  // <-- yaha apna Lottie JSON file daalo
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),

                        // Padding(
                        //   padding:  EdgeInsets.only(left:40.sp,right: 40.sp),
                        //   child: Text(
                        //     "Exam Not Available",
                        //     textAlign: TextAlign.center,
                        //     style: GoogleFonts.poppins(
                        //       fontSize: 18.sp,
                        //       fontWeight: FontWeight.bold,
                        //       color: Colors.redAccent,
                        //       shadows: [
                        //         Shadow(
                        //           blurRadius: 15,
                        //           color: Colors.blueAccent.withOpacity(0.7),
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                )

              else ...[
                // -------- SUBJECT LIST GENERATION ----------
                ...List.generate(subjects.length, (index) {
                  var subject = subjects[index];
                  List exams = subject["exams"] ?? [];

                  // ---------- IF NO EXAMS IN THIS SUBJECT -> HIDE ----------
                  if (exams.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  // ---------- SHOW SUBJECT TILE ----------
                  return subjectTile(
                    title: subject["title"] ?? "Subject",
                    expanded: subjectExpanded[index],
                    onToggle: () {
                      setState(() {
                        subjectExpanded[index] = !subjectExpanded[index];
                      });
                    },
                    exams: exams.map<Widget>((exam) {
                      return examItem(
                        exam["exam_title"] ?? exam["exam_name"] ?? "Exam",
                        (exam["obtained"] as num?)?.toInt() ?? 0,
                        (exam["report_marks"] as num?)?.toInt() ?? 0,
                      );
                    }).toList(),
                  );
                }),
              ]
            ],
          ),
        )
      ],
    );
  }

  // ----------------------------------------------------------------
  // SUBJECT TILE (NOW EXPAND/COLLAPSE)
  // ----------------------------------------------------------------
  Widget subjectTile({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required List<Widget> exams,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // HEADER WITH ARROW
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration:  BoxDecoration(
                color:AppColors2.primary,

              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),

                  // Rotating arrow
                  AnimatedRotation(
                    turns: expanded ? 0 : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(Icons.keyboard_arrow_up,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // EXAM ITEMS (only if expanded)
          if (expanded) ...exams,
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // EXAM ITEM
  // ----------------------------------------------------------------
  Widget examItem(String name, int obtained, int maxMarks) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Exam  $name",
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Marks  $obtained",
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
              Text("Max  ${maxMarks.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}



// ----------------------- UI Widgets ------------------------------

Widget subjectTileAlwaysOpen({required String title, required List<Widget> exams}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade200,
          blurRadius: 4,
          offset: const Offset(0, 3),
        )
      ],
    ),
    child: Column(
      children: [
        // Subject Name
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),

        // Exam Items List
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(children: exams),
        )
      ],
    ),
  );
}

Widget examItem(String name, int obtained, int maxMarks) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        Text("$obtained / $maxMarks",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

