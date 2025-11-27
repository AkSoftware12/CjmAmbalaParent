import 'package:avi/HexColorCode/HexColor.dart';
import 'package:flutter/material.dart';

class AppColors {
  // static  Color primary = HexColor('#FF2C2C');
  static  Color primary = Colors.red.shade500;
   static  Color secondary =Colors.red.shade500;
  // static  Color secondary41 =HexColor('#FF2C2C');






  static const Color grey = Color(0xFFAAAEB2); // Secondary color (gray)
  static const Color background = Color(0xFFF8F9FA); // Light background color
  static const Color textblack = Color(0xFF212529); // Dark text color
    static const Color textwhite = Color.fromARGB(255, 255, 255, 255); // Dark text color
  static const Color error = Color(0xFFDC3545); // Error color (red)
  static const Color success = Color(0xFF28A745); // Success color (green)
  static const Color yellow = Color(0xFFCCAB21); // Success color (green)
}

class AppColors2 {

  static  Color primary = Colors.red.shade500;
  static  Color secondary =Colors.red.shade500;

  // static  Color primary = HexColor('#f5f1e0'); // Example primary color (blue)
  // static  Color secondary =HexColor('#7da4d1'); // Secondary color (gray)
  static const Color grey =  Color.fromARGB(255, 255, 255, 255); // Secondary color (gray)
  static const Color background = Color(0xFFF8F9FA); // Light background color
  static const Color textblack =  Color.fromARGB(255, 255, 255, 255); // Dark text color
  static const Color textwhite = Color.fromARGB(255, 255, 255, 255); // Dark text color
  // static  Color textwhite = Colors.grey.shade500; // Dark text color
  static const Color error = Color(0xFFDC3545); // Error color (red)
  static const Color success = Color(0xFF28A745); // Success color (green)
  static const Color yellow = Color(0xFFCCAB21); // Success color (green)
}

class AppAssets {
  static const String logo = 'assets/images/logo.png'; 
  static const String cjm = 'assets/cjm.png';
  static const String cjmlogo = 'assets/playstore.png';
}

class ApiRoutes {


  // Gallery App url


  // Main App Url
  static const String baseUrl = "https://softcjm.cjmambala.co.in/api";
  static const String baseUrlNewUser = "https://cjmambala.co.in/api";

  // exam url
  static const String baseExamUrl = "https://exam.cjmambala.co.in/api/";


    // Doownload Main url
  static const String downloadUrl = "https://softcjm.cjmambala.co.in/student/fee-receipt/";
  static const String newUserdownloadUrl = "https://cjmambala.co.in/api/fees/";



// Local  App Url

  // static const String baseUrlNewUser = "http://192.168.1.5/cjmweb/api";
  // static const String baseUrl = "http://192.168.1.9/cjm_ambala12/api";
  //
  // // Download local url
  // static const String downloadUrl = "http://192.168.1.9/cjmweb/student/fee-receipt/";
  // static const String newUserdownloadUrl = "http://192.168.1.9/cjm_ambala12/api/fees/";



  // New Admission Api
  static const String loginNewUser = "$baseUrlNewUser/login";
  static const String loginstudentNewUser = "$baseUrlNewUser/loginstudent";
  static const String getProfileNewUser = "$baseUrlNewUser/student-get";
  static const String msgMarkSeenNewUser = "$baseUrlNewUser/mark-seen";
  static const String orderCreateNewUser  = "$baseUrlNewUser/initiatepayment";
  static const String payFeesNewUser  = "$baseUrlNewUser/payfees";
  static const String admissionDownload  = "$baseUrlNewUser/profile/";





// Student Api


  static const String login = "$baseUrl/login";
  static const String loginstudent = "$baseUrl/loginstudent";
  static const String clear = "$baseUrl/clear";
  static const String getProfile = "$baseUrl/student-get";
  static const String getPhotos = "$baseUrlNewUser/getPhotos";
  static const String getVideos = "$baseUrlNewUser/getVideos";
  static const String getDashboard = "$baseUrl/dashboard";
  static const String getFees = "$baseUrl/get-fees";
  static const String getAssignments = "$baseUrl/get-assignments";
  static const String getTimeTable = "$baseUrl/get-class-routine?day=";
  static const String getSubject = "$baseUrl/get-subjects";
  static const String studentDashboard = "$baseUrl/dashboard";
  static const String uploadAssignment = "$baseUrl/submit-assignments";
  static const String attendance = "$baseUrl/get-attendance-monthly";
  static const String events = "$baseUrl/events";
  static const String getlibrary = "$baseUrl/library-get";
  static const String notifications = "$baseUrl/notifications";
  static const String getBookTypes = "$baseUrl/book-types";
  static const String getBookCategories = "$baseUrl/book-categories";
  static const String getBookPublishers = "$baseUrl/book-publishers";
  static const String getBookSupplier= "$baseUrl/book-supplier";
  static const String getAtomSettings= "$baseUrl/atom-settings";
  static const String orderCreate= "$baseUrl/bulkpay";
  static const String atompay= "$baseUrl/atompay";
  static const String passwordChange= "$baseUrl/change-password";
  static const String updateApk= "$baseUrl/update-apk";
  static const String forgotPassword= "$baseUrl/forgot-password";
  static const String verifyOtp= "$baseUrl/verifyOtp";
  static const String applyleave= "$baseUrl/applyleave";

  static const String getAllMessages = "$baseUrl/messages";
  static const String getUserMessagesConversation = "$baseUrl/messages/conversation/";
  static const String sendMessage = "$baseUrl/messages";



  // Teacher Api

  static const String teacherlogin = "$baseUrl/teacher-login";
  static const String getTeacheProfile = "$baseUrl/teacher";
  static const String getTeacherPhotos = "$baseUrlNewUser/getPhotos";
  static const String getTeacherVideos = "$baseUrlNewUser/getVideos";
  static const String getTeacherlibrary = "$baseUrl/library-get";
  static const String getTeacherBookTypes = "$baseUrl/book-types";
  static const String getTeacherBookCategories = "$baseUrl/book-categories";
  static const String getTeacherBookPublishers = "$baseUrl/book-publishers";
  static const String getTeacherBookSupplier= "$baseUrl/book-supplier";
  static const String uploadTeacherAssignment = "$baseUrl/teacher-assignment";
  static const String deleteTeacherAssignment = "$baseUrl/teacher-assignment-delete";
  static const String getTeacherDashboard = "$baseUrl/dashboard";
  static const String getTeacherFees = "$baseUrl/get-fees";
  static const String getTeacherAssignments = "$baseUrl/teacher-assignment";
  // static const String getTimeTable = "$baseUrl/teacher-subjects";
  static const String getTeacherTimeTable = "$baseUrl/teacher-timetable?day=";
  static const String getTeacherSubject = "$baseUrl/get-subjects";
  static const String studentTeacherDashboard = "$baseUrl/dashboard";
  static const String Teacherattendance = "$baseUrl/get-attendance-monthly";
  static const String Teacherevents = "$baseUrl/events";
  static const String TeachergetTeacherBanners = "$baseUrl/get-banners";
  static const String Teachernotifications = "$baseUrl/teacher-notifications";
  static const String getTeacherClass = "$baseUrl/teacher-student-atttendance";
  static const String getTeacherTeacherSubject = "$baseUrl/teacher-assigned-subjects";
  static const String getTeacherAllStudents1 = "$baseUrl/teachers/students";
  static const String getTeacherStudentsProfile = "$baseUrl/teachers/students/";
  static const String getTeacherAllStudents = "$baseUrl/teachers/students?class=1&section=1";



  static const String getAllTeacherMessages = "$baseUrl/teacher/messages";
  static const String getTeacherMessagesConversation = "$baseUrl/teacher/messages/conversation/";
  static const String sendTeacherMessage = "$baseUrl/teacher/messages/send";
}
