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
  // await Future.delayed(Duration(seconds: 5));
  // UpdateChecker.checkForUpdate(navigatorKey.currentContext!);
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





// class NotificationService {
//   static final FirebaseMessaging _firebaseMessaging =
//       FirebaseMessaging.instance;
//   static final FlutterLocalNotificationsPlugin
//   _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//
//   /// **🔹 Initialize Notifications**
//   static Future<void> initNotifications() async {
//     // **Request Permission for Push Notifications**
//     NotificationSettings settings = await _firebaseMessaging.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//
//     if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//       if (kDebugMode) {
//         print("✅ Push Notifications Enabled");
//       }
//
//       // **Get FCM Token**
//       String? token = await _firebaseMessaging.getToken();
//       if (kDebugMode) {
//         print("FCM Token: $token");
//       } // Send this to your server
//
//       // **Handle Incoming Notifications**
//       FirebaseMessaging.onMessage.listen(_onMessage);
//       FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
//       FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
//
//       // **Initialize Local Notifications**
//       _initLocalNotifications();
//     } else {}
//   }
//
//   /// **🔹 Handle Foreground Notifications**
//   static void _onMessage(RemoteMessage message) {
//     _showLocalNotification(message);
//   }
//
//   /// **🔹 Handle Notification Click**
//   static void _onMessageOpenedApp(RemoteMessage message) {
//     // **Navigate to a Specific Screen**
//     // Navigator.push(
//     //   context,
//     //   MaterialPageRoute(builder: (context) => NotificationScreen()),
//     // );
//     // Navigate to the relevant screen based on message.data
//   }
//
//   /// **🔹 Handle Background Notifications**
//   static Future<void> _onBackgroundMessage(RemoteMessage message) async {}
//
//   /// **🔹 Initialize Local Notifications**
//   static void _initLocalNotifications() {
//     const AndroidInitializationSettings androidSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     const InitializationSettings settings = InitializationSettings(
//       android: androidSettings,
//     );
//
//     _flutterLocalNotificationsPlugin.initialize(settings);
//   }
//
//   /// **🔹 Show Local Notification**
//   static Future<void> _showLocalNotification(RemoteMessage message) async {
//     const AndroidNotificationDetails androidDetails =
//         AndroidNotificationDetails(
//           'channelId',
//           'channelName',
//           importance: Importance.max,
//           priority: Priority.high,
//         );
//
//     const NotificationDetails generalNotificationDetails = NotificationDetails(
//       android: androidDetails,
//     );
//
//     await _flutterLocalNotificationsPlugin.show(
//       0,
//       message.notification?.title,
//       message.notification?.body,
//       generalNotificationDetails,
//     );
//   }
// }


class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
  AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
  );

  /// Initialize notifications
  static Future<void> initNotifications() async {
    await Firebase.initializeApp();

    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print("✅ Push Notifications Enabled");
      }

      await _initLocalNotifications();

      // iOS foreground notification settings
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print("FCM Token: $token");
      }

      // Foreground
      FirebaseMessaging.onMessage.listen(_onMessage);

      // App opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      // Background/terminated
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    }
  }

  /// Foreground notification
  static void _onMessage(RemoteMessage message) {
    // Foreground me local notification dikha do
    _showLocalNotification(message);
  }

  /// Notification click
  static void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print("Notification clicked: ${message.data}");
    }

    // Yaha screen navigation kar sakte ho
    // example:
    // final type = message.data['type'];
    // if (type == 'chat') { ... }
  }

  /// Background message handler
  @pragma('vm:entry-point')
  static Future<void> _onBackgroundMessage(RemoteMessage message) async {
    await Firebase.initializeApp();
  }

  /// Init local notifications
  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          print('Notification payload: ${response.payload}');
        }
      },
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  /// Show local notification with full text
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final String title =
        message.notification?.title ??
            message.data['title']?.toString() ??
            'Notification';

    final String body =
        message.notification?.body ??
            message.data['body']?.toString() ??
            '';

    final BigTextStyleInformation bigTextStyleInformation =
    BigTextStyleInformation(
      body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: 'Tap to open',
      htmlFormatSummaryText: false,
    );

    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      ticker: 'ticker',
      styleInformation: bigTextStyleInformation,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }
}


