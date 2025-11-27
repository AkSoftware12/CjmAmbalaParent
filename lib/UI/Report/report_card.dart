import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportCardScreen extends StatelessWidget {
  // Sample data for the report card
  final List<Map<String, dynamic>> subjects = [
    {"subject": "Mathematics", "marks": 90, "total": 100},
    {"subject": "Science", "marks": 85, "total": 100},
    {"subject": "English", "marks": 88, "total": 100},
    {"subject": "History", "marks": 75, "total": 100},
    {"subject": "Geography", "marks": 92, "total": 100},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          'Report Card',
          style: GoogleFonts.montserrat(),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Student Name: John Doe",
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Class: 10",
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Roll No: 23",
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Report Card List
            Expanded(
              child: ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Text(
                        subject['subject'],
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        "Marks: ${subject['marks']} / ${subject['total']}",
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: Text(
                        "${((subject['marks'] / subject['total']) * 100).toStringAsFixed(1)}%",
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


