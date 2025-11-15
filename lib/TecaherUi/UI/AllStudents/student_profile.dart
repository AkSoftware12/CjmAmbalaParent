import 'package:avi/constants.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  String selectedYear = "2025-2026";

  // PAGE CONTROLLER
  final PageController _pageController = PageController();
  int currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Column(
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

          // ---------------- STUDENT INFO ----------------
          Row(
            children: [
              Padding(
                padding: EdgeInsets.all(10.sp),
                child: CircleAvatar(
                  radius: 45.sp,
                  backgroundImage: const NetworkImage(
                    "https://cdn-icons-png.flaticon.com/512/149/149071.png",
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("AARIKA", style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Class: LKG-A",
                      style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                  Text("Admission No.: 1234",
                      style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                  Text("DOJ: 2023",
                      style: GoogleFonts.poppins(color: Colors.grey.shade700)),
                ],
              )
            ],
          ),

          const Divider(thickness: 1.5, color: Colors.grey),

          // ---------------- PAGEVIEW CONTENT ----------------
          Expanded(
            child: Column(
              children: [
                // 🔥 PAGE VIEW HERE 🔥
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => currentPage = index);
                    },
                    children: [
                      attendancePage(),
                      performancePage(),
                      feePage(),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  bottomTab("Attendance", 0),
                  bottomTab("Academic Performance", 1),
                  bottomTab("Fee Details", 2),
                  bottomTab("Library", 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Bottom Tab ----------------
  Widget bottomTab(String title, int index) {
    bool active = currentPage == index;

    return GestureDetector(
      onTap: () {
        setState(() => currentPage = index);
        _pageController.animateToPage(index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      },
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: active ? AppColors2.primary : Colors.black,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
        ),
        // style: GoogleFonts.poppins(
        //   color: active ? Colors.white : Colors.black,
        //   fontWeight: active ? FontWeight.bold : FontWeight.normal,
        //   fontSize: active ? 14.sp : 12.sp,
        // ),
      ),
    );
  }

  // -------------------- PAGE 1: Attendance --------------------
  Widget attendancePage() {
    return SingleChildScrollView(
      child: Padding(
        padding:  EdgeInsets.all(10.sp),
        child: Column(
          children: [

            // ---------------- Academic Year Dropdown ----------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Academic year:",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey.shade200,
                  ),
                  child: DropdownButton<String>(
                    value: selectedYear,
                    underline: const SizedBox(),
                    items: [
                      "2024-2025",
                      "2025-2026",
                      "2026-2027"
                    ].map((e) {
                      return DropdownMenuItem<String>(
                        value: e,
                        child: Text(e),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedYear = val!),
                  ),
                )
              ],
            ),


            // ---------------- Donut Chart ----------------
            Center(
              child: Row(
                children: [
                  SizedBox(
                    height: 160.sp,
                    width: 120.sp,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 50,
                        sectionsSpace: 2,
                        sections: [
                          PieChartSectionData(
                            value: 100,
                            color: Colors.green,
                            radius: 30,
                            title: "",
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ---------------- Stats Labels ----------------
                  SizedBox(
                    width: 10.sp,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        statRow("Present", Colors.green, "100.0%"),
                        statRow("Working Holiday", Colors.purple, "0.0%"),
                        statRow("Total Present", Colors.green, "100.0%"),
                        statRow("Leave", Colors.yellow.shade700, "0.0%"),
                        statRow("Absent", Colors.red, "0.0%"),
                        statRow("Late", Colors.orange, "0.0%"),
                      ],
                    ),
                  ),
                ],
              ),
            ),




            const SizedBox(height: 10),

            // ---------------- Table Heading ----------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                tableHeader("Months"),
                tableHeader("Working Days"),
                tableHeader("Total Present"),
                tableHeader("Present"),
                tableHeader("Holiday"),
                tableHeader("Absent"),
                tableHeader("Leave"),
                tableHeader("Late"),
              ],
            ),
            const SizedBox(height: 10),

            // ---------------- Table Rows ----------------
            buildRow("April", 17),
            buildRow("May", 18),
            buildRow("July", 19),
            buildRow("August", 22),
            buildRow("September", 16),
            buildRow("October", 19),
            buildRow("November", 8),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // -------------------- PAGE 2 --------------------
  Widget performancePage() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [



          // ---------------- Academic Year Selection ----------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Academic year:",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey.shade200),
                  child: DropdownButton<String>(
                    value: "2025-2026",
                    underline: const SizedBox(),
                    items: [
                      "2024-2025",
                      "2025-2026",
                      "2026-2027"
                    ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) {},
                  ),
                )
              ],
            ),
          ),

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

  // -------------------- PAGE 3 --------------------
  Widget feePage() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(12.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),

              // ---------------- Header Row ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dropdown
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: "2025-2026",
                      underline: SizedBox(),
                      items: [
                        "2024-2025",
                        "2025-2026",
                        "2026-2027",
                      ].map((e) {
                        return DropdownMenuItem(value: e, child: Text(e));
                      }).toList(),
                      onChanged: (v) {},
                    ),
                  ),

                  // Paid Transaction Button
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "View paid transaction",
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  )
                ],
              ),

              SizedBox(height: 20),

              // ---------------- TABLE HEADER ----------------
              Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: _tableHeader("Installment")),
                  Expanded(child: _tableHeader("Actual Fee")),
                  Expanded(child: _tableHeader("Concession")),
                  Expanded(child: _tableHeader("Received")),
                  Expanded(child: _tableHeader("Outstanding")),
                ],
              ),

              Divider(),

              // ---------- Row 1 ----------
              _feeRow(
                "Fees April-June",
                "34795.0",
                "0.0",
                "34795.0",
                "0.0",
              ),

              Divider(),

              // ---------- Row 2 ----------
              _feeRow(
                "Fees July-September",
                "14395.0",
                "0.0",
                "14395.0",
                "0.0",
              ),

              Divider(),

              // ---------- Row 3 ----------
              _feeRow(
                "Fees October-December",
                "14395.0",
                "0.0",
                "14395.0",
                "0.0",
              ),

              Divider(),

              // ---------- Row 4 ----------
              _feeRow(
                "Fees January-March",
                "14395.0",
                "0.0",
                "0.0",
                "14395.0",
              ),

              Divider(),

              // ------------ TOTAL ROW ---------------
              Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text(
                        "Total",
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      )),
                  Expanded(child: Text("77980.0")),
                  Expanded(child: Text("0.0")),
                  Expanded(child: Text("63585.0")),
                  Expanded(child: Text("14395.0")),
                ],
              ),


              // ----------------- PIE CHART -------------------
              Row(
                children: [
                  SizedBox(
                    height: 260,
                    width: 200,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 50,
                        sections: [
                          PieChartSectionData(
                            value: 81.54,
                            color: Colors.green,
                            radius: 30,
                          ),
                          PieChartSectionData(
                            value: 18.46,
                            color: Colors.red,
                            radius: 30,
                          ),
                          PieChartSectionData(
                            value: 0,
                            color: Colors.grey,
                            radius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legend(Colors.green, "Received (81.54%)"),
                      SizedBox(width: 10),
                      _legend(Colors.red, "Outstanding (18.46%)"),
                      SizedBox(width: 10),
                      _legend(Colors.grey, "Concession (0.0%)"),
                    ],
                  )
                ],
              ),



            ],
          ),
        ),
      ),
    );
  }
  Widget _tableHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
    );
  }

  Widget _feeRow(String instal, String fee, String conc, String recv, String out) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            instal,
            style: GoogleFonts.poppins(fontSize: 13),
          ),
        ),
        Expanded(child: Text(fee)),
        Expanded(child: Text(conc)),
        Expanded(child: Text(recv)),
        Expanded(child: Text(out)),
      ],
    );
  }

  Widget _legend(Color c, String txt) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c,
          ),
        ),
        SizedBox(width: 4),
        Text(
          txt,
          style: GoogleFonts.poppins(fontSize: 14,fontWeight: FontWeight.bold),
        ),
      ],
    );
  }


  // -------------------- PAGE 4 --------------------
  Widget libraryPage() {
    return Center(
      child: Text("Library",
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  // =================== Widgets ===================

  Widget statRow(String title, Color color, String percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(height: 12,
              width: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text("$title ($percent)", style: GoogleFonts.poppins(fontSize: 14)),
        ],
      ),
    );
  }

  Widget tableHeader(String txt) {
    return Expanded(
      child: Text(txt, style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold, fontSize: 12)),
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