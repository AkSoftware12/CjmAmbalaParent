import 'package:avi/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AssignmentDetailScreen extends StatelessWidget {
  final Map<String, dynamic> assignment;

  const AssignmentDetailScreen({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Assignment Detail',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildStatusBadge(assignment['attendance_status']??'N/A'),
          ),

        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleCard(),
            const SizedBox(height: 10),
            _buildDateCard(),
            const SizedBox(height: 10),
            _buildDescriptionCard(),
            const SizedBox(height: 30),
            _buildAttachmentButton(context),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }


  Widget _buildStatusBadge(String status) {
    final isPending = status == 'pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPending ? 'Pending' : status.toUpperCase(),
        style:  TextStyle(
          color:  isPending
              ? Colors.red
              : Colors.green,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDateItem(
              icon: Icons.calendar_today_outlined,
              label: 'Start Date',
              value: _formatDate(assignment['start_date']??'N/A'),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: const Color(0xFFFFCDD2),
          ),
          Expanded(
            child: _buildDateItem(
              icon: Icons.event_outlined,
              label: 'Due Date',
              value: _formatDate(assignment['due_date']??'N/a'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Icon(icon, color:AppColors.primary, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style:  TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style:  TextStyle(
              color: Color(0xFF212121),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
               Text(
                'Description',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            assignment['description'] ?? 'N/A',
            style:  TextStyle(
              color: Color(0xFF424242),
              fontSize: 12.sp,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTitleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
               Text(
                'Title',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            assignment['title'] ?? 'N/A',
            style:  TextStyle(
              color: AppColors.primary,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton(BuildContext context) {
    final attachUrl = assignment['attach'];
    if (attachUrl == null || attachUrl.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final url = assignment['attach'].toString();
          if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
          } else {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
          content: Text('Could not open file')),
          );
          }
        },
        icon: const Icon(Icons.attach_file_rounded, size: 20),
        label:  Text(
          'View Attachment',
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }


  String _formatDate(String? rawDate) {
    try {
      if (rawDate == null || rawDate.isEmpty) return "N/A";
      return DateFormat('dd - MM - yyyy').format(DateTime.parse(rawDate));
    } catch (_) {
      return "N/A";
    }
  }
}