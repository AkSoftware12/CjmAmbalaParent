import 'dart:convert';
import 'dart:io';
import 'package:avi/HexColorCode/HexColor.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../splash_sreen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'constants.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();



  Platform.isAndroid
      ? await Firebase.initializeApp(
          options: kIsWeb || Platform.isAndroid
              ? const FirebaseOptions(
                  apiKey: 'AIzaSyBhuh_2exvng2cYi1-WVG8AWFGFgLjRYQM',
                  appId: '1:1012918033516:android:0b6718b40f48b55cb84c49',
                  messagingSenderId: '1012918033516',
                  projectId: 'cjm-ambala',
                  storageBucket: "cjm-ambala.firebasestorage.app",
                )
              : null,
        )
      : await Firebase.initializeApp();
  NotificationService.initNotifications();
  FirebaseMessaging.instance.getToken().then((token) {});
  // Portrait Only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(ProviderScope(child: MyApp(navigatorKey: navigatorKey)));

  // runApp(const MyApp());
  // Wait 5 seconds then show update dialog
  await Future.delayed(Duration(seconds: 5));
  UpdateChecker.checkForUpdate(navigatorKey.currentContext!);
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      // Use builder only if you need to use library outside ScreenUtilInit context
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey, // ⬅️ Add this
          home: SplashScreen(),
        );
      },
    );
  }
}

class UpdateChecker {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      // **Step 1: Get Current App Version**
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      final response = await http.get(Uri.parse(ApiRoutes.updateApk));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        String latestVersion = data['data']['version'].toString();
        String apkUrl = data['data']['url'].toString();
        String releaseNotes =
            html_parser
                .parse(data['data']['release_notes'].toString())
                .body
                ?.text ??
            '';

        // For iOS, use static version check
        if (Platform.isIOS) {
          // Static version for iOS
          String currentIOSVersion = "1.0.17";
          print(Platform.isIOS);
          print('Current Version : $currentIOSVersion');
          print('Latest iOS Version : $latestVersion');

          // Compare versions for iOS
          if (_isNewVersionAvailable(currentIOSVersion, latestVersion)) {
            _showIOSUpdateDialog(context);
          }
          return; // Exit early for iOS
        }

        print('Current Version : $currentVersion');
        print('Latest Version : $latestVersion');

        // **Step 3: Compare Versions**
        if (_isNewVersionAvailable(currentVersion, latestVersion)) {
          _showUpdateDialog(context, apkUrl);
        }

        if (releaseNotes != null &&
            releaseNotes.trim().isNotEmpty &&
            releaseNotes.toLowerCase() != 'null') {
          showNewsDialog(context, releaseNotes, releaseNotes);
        }
      }
    } catch (e) {
      print("Error checking update: $e");
    }
  }

  static bool _isNewVersionAvailable(String current, String latest) {
    List<int> currVer = current.split('.').map(int.parse).toList();
    List<int> latestVer = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < latestVer.length; i++) {
      if (i >= currVer.length || latestVer[i] > currVer[i]) return true;
      if (latestVer[i] < currVer[i]) return false;
    }
    return false;
  }



  static void _showUpdateDialog(BuildContext context, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents dismissal on outside click
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevents dismissal on back button
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 60.sp),
                  child: Container(
                    height: 280.sp,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 50.sp),
                        // Title
                        Text(
                          "App Update Required!",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        // Description
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "We have added new features and fixed some bugs to make your experience seamless.",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 12.sp,
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 30.sp),
                        // Update Button
                        _UpdateButton(apkUrl: apkUrl),
                      ],
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/rocket_update.png',
                        height: 130.sp,
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
  }
  // For iOS app updates
  static void _showIOSUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.only(top: 20),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 10,
          ),
          actionsPadding: const EdgeInsets.only(bottom: 10, right: 10),
          title: Column(
            children: [
              SizedBox(height: 25.sp),
              Icon(Icons.system_update, size: 55.sp, color: Colors.blueAccent),
              SizedBox(height: 20.sp),
              Text(
                "New Update Available".toString().toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.sp),
            ],
          ),
          content: Padding(
            padding: EdgeInsets.only(bottom: 18.sp),
            child: Text(
              "A new version of this app is available on the App Store. Please update to the latest version to enjoy new features and improvements.",
              style: GoogleFonts.poppins(
                textStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                // Open App Store
                final appStoreUrl =
                    'https://apps.apple.com/in/app/cjm-shimla/id6744753885'; // Replace with your App Store URL
                if (await canLaunchUrl(Uri.parse(appStoreUrl))) {
                  await launchUrl(
                    Uri.parse(appStoreUrl),
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  print("Could not open App Store link.");
                }
              },
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              label: Text(
                "Update Now".toString().toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static void showNewsDialog(
    BuildContext context,
    String title,
    String description,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Container(
            padding: EdgeInsets.all(16),
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // News Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/construction.gif',
                    height: 100.sp,
                    width: 100.sp,
                    fit: BoxFit.cover,
                  ),
                ),

                SizedBox(height: 16.sp),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                SizedBox(height: 20),

                // Dismiss Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white),
                  label: Text("Close", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// **🔹 Initialize Notifications**
  static Future<void> initNotifications() async {
    // **Request Permission for Push Notifications**
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print("✅ Push Notifications Enabled");
      }

      // **Get FCM Token**
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print("FCM Token: $token");
      } // Send this to your server

      // **Handle Incoming Notifications**
      FirebaseMessaging.onMessage.listen(_onMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

      // **Initialize Local Notifications**
      _initLocalNotifications();
    } else {}
  }

  /// **🔹 Handle Foreground Notifications**
  static void _onMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }

  /// **🔹 Handle Notification Click**
  static void _onMessageOpenedApp(RemoteMessage message) {
    // **Navigate to a Specific EbooksScreen**
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (context) => NotificationScreen()),
    // );
    // Navigate to the relevant screen based on message.data
  }

  /// **🔹 Handle Background Notifications**
  static Future<void> _onBackgroundMessage(RemoteMessage message) async {}

  /// **🔹 Initialize Local Notifications**
  static void _initLocalNotifications() {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    _flutterLocalNotificationsPlugin.initialize(settings);
  }

  /// **🔹 Show Local Notification**
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'channelId',
          'channelName',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails generalNotificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title,
      message.notification?.body,
      generalNotificationDetails,
    );
  }
}

class _UpdateButton extends StatefulWidget {
  final String apkUrl;

  const _UpdateButton({required this.apkUrl});

  @override
  __UpdateButtonState createState() => __UpdateButtonState();
}

class __UpdateButtonState extends State<_UpdateButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: HexColor('535ac4'),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      onPressed: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              try {
                if (await canLaunchUrl(Uri.parse(widget.apkUrl))) {
                  await launchUrl(
                    Uri.parse(widget.apkUrl),
                    mode: LaunchMode.externalApplication,
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Could not open update link")),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              } finally {
                setState(() => _isLoading = false);
              }
            },

      label: Text(
        "Update  App",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 15.sp,
          color: Colors.white,
        ),
      ),
    );
  }
}
