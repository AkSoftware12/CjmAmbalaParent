import 'dart:convert';
import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceSummaryScreen extends StatefulWidget {
  const AttendanceSummaryScreen({super.key});

  @override
  State<AttendanceSummaryScreen> createState() =>
      _AttendanceSummaryScreenState();
}

class _AttendanceSummaryScreenState extends State<AttendanceSummaryScreen> {

  bool isLoading=false;
  String? errorMessage;

  DateTime selectedDate=DateTime.now();

  List<AttendanceRow> rows=[];

  int totalPresent=0;
  int totalAbsent=0;
  int totalLeave=0;
  int grandTotal=0;

  static const Color red = Color(0xffd32f2f);

  @override
  void initState() {
    super.initState();
    fetchAttendanceSummary();
  }

  Future<void> fetchAttendanceSummary() async {

    setState(() {
      isLoading=true;
      errorMessage=null;
    });

    try{

      final prefs=await SharedPreferences.getInstance();
      final token=prefs.getString('teachertoken');

      if(token==null || token.isEmpty){
        setState(() {
          errorMessage="Token not found";
          isLoading=false;
        });
        return;
      }

      final date=DateFormat('yyyy-MM-dd').format(selectedDate);

      final url=Uri.parse(
          '${ApiRoutes.getAttendanceSummary}$date'
      );

      final response=await http.get(
        url,
        headers: {
          "Accept":"application/json",
          "Authorization":"Bearer $token"
        },
      );

      if(response.statusCode==200){

        final jsonData=jsonDecode(response.body);

        final List list=jsonData['data']?['rows'] ?? [];
        final totals=jsonData['data']?['totals'] ?? {};

        setState(() {

          rows=list.map((e)=>
              AttendanceRow.fromJson(e)
          ).toList();

          totalPresent=_toInt(totals['present']);
          totalAbsent=_toInt(totals['absent']);
          totalLeave=_toInt(totals['leave']);
          grandTotal=_toInt(totals['total']);

        });

      }else{
        errorMessage="Server Error ${response.statusCode}";
      }

    }catch(e){
      errorMessage=e.toString();
    }

    setState(() {
      isLoading=false;
    });

  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            colorScheme: ColorScheme.light(
              primary: Colors.red, // Header bg + selected date
              onPrimary: Colors.white, // Header text
              onSurface: Colors.black87, // Calendar text
              surface: Colors.white,
            ),

            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,

              headerBackgroundColor: Colors.red,
              headerForegroundColor: Colors.white,

              dayForegroundColor:
              WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.black87;
              }),

              dayBackgroundColor:
              WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.red;
                }
                return null;
              }),

              todayForegroundColor:
              WidgetStateProperty.all(Colors.red),

              todayBorder: BorderSide(
                color: Colors.red,
                width: 1.5,
              ),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });

      fetchAttendanceSummary();
    }
  }
  @override
  Widget build(BuildContext context) {

    final displayDate=
    DateFormat('dd-MM-yyyy').format(selectedDate);

    return Scaffold(

      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          children: [

            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.06),
                    blurRadius: 8,
                  )
                ],
              ),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [

                      Expanded(
                        child: InkWell(
                          onTap: pickDate,
                          child: Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal:14,
                              vertical:10,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: red.withOpacity(.3)
                              ),
                              borderRadius:
                              BorderRadius.circular(12),
                              color: Colors.red.shade50,
                            ),
                            child: Row(
                              children: [

                                const Icon(
                                  Icons.calendar_month,
                                  color: red,
                                ),

                                const SizedBox(width:8),

                                Expanded(
                                  child: Text(
                                    displayDate,
                                    style: const TextStyle(
                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width:10),

                      ElevatedButton(
                        style:
                        ElevatedButton.styleFrom(
                          backgroundColor: red,
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal:20,
                            vertical:5,
                          ),
                        ),
                        onPressed: fetchAttendanceSummary,
                        child: const Text(
                          "Show",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      )
                    ],
                  )

                ],
              ),
            ),

            const SizedBox(height:10),

            Expanded(
              child: isLoading
                  ? const Center(
                child:
                CircularProgressIndicator(
                  color: red,
                ),
              )
                  : errorMessage!=null
                  ? Center(
                child: Text(
                  errorMessage!,
                ),
              )
                  : rows.isEmpty
                  ? const Center(
                child: Text(
                    "No data found"
                ),
              )
                  : SingleChildScrollView(
                scrollDirection:
                Axis.horizontal,

                child: SingleChildScrollView(
                  child: DataTable(

                    headingRowColor:
                    MaterialStateProperty.all(
                        red
                    ),

                    border: TableBorder.all(
                      color: Colors.grey.shade300,
                    ),

                    columnSpacing: 30,

                    headingTextStyle:
                    const TextStyle(
                      color: Colors.white,
                      fontWeight:
                      FontWeight.bold,
                    ),

                    dataTextStyle:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      color: Colors.black,
                    ),

                    columns: const [

                      DataColumn(
                        label: Center(
                          child: Text(
                            'Sr, No.',
                            textAlign:
                            TextAlign.center,
                          ),
                        ),
                      ),

                      DataColumn(
                        label: Center(
                          child: Text(
                            'Class',
                            textAlign:
                            TextAlign.center,
                          ),
                        ),
                      ),

                      DataColumn(
                        label: Center(
                          child: Text(
                            'Present',
                            textAlign:
                            TextAlign.center,
                          ),
                        ),
                      ),

                      DataColumn(
                        label: Center(
                          child: Text(
                            'Absent',
                            textAlign:
                            TextAlign.center,
                          ),
                        ),
                      ),

                      DataColumn(
                        label: Center(
                          child: Text(
                            'Leave',
                            textAlign:
                            TextAlign.center,
                          ),
                        ),
                      ),

                      DataColumn(
                        label: Center(
                          child: Text(
                            'Total',
                            textAlign:
                            TextAlign.center,
                          ),
                        ),
                      ),

                      DataColumn(
                        label: Center(
                          child: Text(
                            'Status',
                            textAlign:
                            TextAlign.center,
                          ),
                        ),
                      ),

                    ],

                    rows: [

                      ...List.generate(
                        rows.length,
                            (index){

                          final item=rows[index];

                          return DataRow(

                            color:
                            MaterialStateProperty.all(
                              index.isEven
                                  ? Colors.white
                                  : Colors.red.shade50,
                            ),

                            cells: [

                              DataCell(
                                Center(
                                  child: Text(
                                      '${index+1}'
                                  ),
                                ),
                              ),

                              DataCell(
                                Center(
                                  child: Text(
                                    '${item.classTitle}-${item.sectionTitle}',
                                    textAlign:
                                    TextAlign.center,
                                  ),
                                ),
                              ),

                              DataCell(
                                Center(
                                  child: Text(
                                      '${item.present}'
                                  ),
                                ),
                              ),

                              DataCell(
                                Center(
                                  child: Text(
                                      '${item.absent}'
                                  ),
                                ),
                              ),

                              DataCell(
                                Center(
                                  child: Text(
                                      '${item.leave}'
                                  ),
                                ),
                              ),

                              DataCell(
                                Center(
                                  child: Text(
                                      '${item.totalMarked}'
                                  ),
                                ),
                              ),

                              DataCell(
                                Center(
                                  child: Container(
                                    padding:
                                    const EdgeInsets.symmetric(
                                      horizontal:10,
                                      vertical:4,
                                    ),
                                    decoration:
                                    BoxDecoration(
                                      color: item.isMissing
                                          ? Colors.red.shade100
                                          : Colors.green.shade100,
                                      borderRadius:
                                      BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      item.isMissing
                                          ? 'Missing'
                                          : 'Marked',
                                      style: TextStyle(
                                        fontWeight:
                                        FontWeight.bold,
                                        color:
                                        item.isMissing
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            ],
                          );

                        },
                      ),

                      DataRow(
                        color:
                        MaterialStateProperty.all(
                            Colors.red.shade100
                        ),

                        cells: [

                          const DataCell(
                            Center(
                              child: Text(""),
                            ),
                          ),

                          const DataCell(
                            Center(
                              child: Text(
                                "TOTAL",
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.w900,
                                  color:red,
                                ),
                              ),
                            ),
                          ),

                          DataCell(
                            Center(
                              child: Text(
                                '$totalPresent',
                                style: const TextStyle(
                                  fontWeight:
                                  FontWeight.w900,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ),

                          DataCell(
                            Center(
                              child: Text(
                                '$totalAbsent',
                                style: const TextStyle(
                                  fontWeight:
                                  FontWeight.w900,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),

                          DataCell(
                            Center(
                              child: Text(
                                '$totalLeave',
                                style: const TextStyle(
                                  fontWeight:
                                  FontWeight.w900,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ),

                          DataCell(
                            Center(
                              child: Text(
                                '$grandTotal',
                                style: const TextStyle(
                                  fontWeight:
                                  FontWeight.w900,
                                  color:red,
                                ),
                              ),
                            ),
                          ),

                          const DataCell(
                            Center(
                              child: Text(
                                "Summary",
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  color:red,
                                ),
                              ),
                            ),
                          ),

                        ],
                      )

                    ],
                  ),
                ),
              ),
            ),



          ],
        ),
      ),
    );
  }
}

class AttendanceRow {

  final String classTitle;
  final String sectionTitle;
  final int present;
  final int absent;
  final int leave;
  final int totalMarked;
  final bool isMissing;

  AttendanceRow({
    required this.classTitle,
    required this.sectionTitle,
    required this.present,
    required this.absent,
    required this.leave,
    required this.totalMarked,
    required this.isMissing,
  });

  factory AttendanceRow.fromJson(
      Map<String,dynamic> json
      ){

    return AttendanceRow(
      classTitle:
      json['class_title']?.toString() ?? '',
      sectionTitle:
      json['section_title']?.toString() ?? '',
      present:_toInt(json['present']),
      absent:_toInt(json['absent']),
      leave:_toInt(json['leave']),
      totalMarked:_toInt(json['total_marked']),
      isMissing:
      json['is_missing']==true ||
          json['is_missing'].toString()=='1',
    );

  }

}

int _toInt(dynamic value){
  if(value is int) return value;
  return int.tryParse(
      value.toString()
  ) ?? 0;
}