import 'dart:convert';
import 'package:avi/strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../HexColorCode/HexColor.dart';
import '../../constants.dart';
// import 'package:flutter/services.dart';



// live key
const req_EncKey = '7ABE0A52322733FFDFE5285649F7B92D';
const req_Salt = '7ABE0A52322733FFDFE5285649F7B92D';
const res_DecKey = '66B7FF4DDA6F547C9CE1700440975C4A';
const res_Salt = '66B7FF4DDA6F547C9CE1700440975C4A';
const resHashKey = "3b9458ce3cd22c66f6";
const authUrl = "https://payment1.atomtech.in/ots/aipay/auth";

String? atomTokenId;
bool isLoading = false;

final password = Uint8List.fromList(utf8.encode(req_EncKey));
final salt = Uint8List.fromList(utf8.encode(req_Salt));
final resPassword = Uint8List.fromList(utf8.encode(res_DecKey));
final resSalt = Uint8List.fromList(utf8.encode(res_Salt));
final iv =
Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);

//Encrypt Function
Future<String> encrypt(String text) async {
  debugPrint('Input text for encryption: $text');
  try {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 65536,
      bits: 256,
    );

    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(password),
      nonce: salt,
    );

    final keyBytes = await derivedKey.extractBytes();
    debugPrint('Derived key bytes: $keyBytes');

    final aesCbc = AesCbc.with256bits(
      macAlgorithm: MacAlgorithm.empty,
      paddingAlgorithm: PaddingAlgorithm.pkcs7,
    );

    final secretBox = await aesCbc.encrypt(
      utf8.encode(text),
      secretKey: SecretKey(keyBytes),
      nonce: iv,
    );

    final hexOutput = secretBox.cipherText
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    debugPrint('Encrypted hex output: $hexOutput');
    return hexOutput;
  } catch (e, stackTrace) {
    debugPrint('Encryption error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}

// Decrypt Function
Future<String> decrypt(String hexCipherText) async {
  try {
    debugPrint('Input hex for decryption: $hexCipherText');

    // Convert hex string to bytes
    List<int> cipherText = [];
    for (int i = 0; i < hexCipherText.length; i += 2) {
      String hex = hexCipherText.substring(i, i + 2);
      cipherText.add(int.parse(hex, radix: 16));
    }
    debugPrint('Cipher text bytes: $cipherText');

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 65536,
      bits: 256,
    );

    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(resPassword),
      nonce: resSalt, // Use the same salt as in encryption
    );

    final keyBytes = await derivedKey.extractBytes();

    final aesCbc = AesCbc.with256bits(
      macAlgorithm: MacAlgorithm.empty,
      paddingAlgorithm: PaddingAlgorithm.pkcs7,
    );

    final secretBox = SecretBox(
      cipherText,
      nonce: iv, // Use the same IV as in encryption
      mac: Mac.empty,
    );
    debugPrint('SecretBox: $secretBox');

    final decryptedBytes = await aesCbc.decrypt(
      secretBox,
      secretKey: SecretKey(keyBytes),
    );

    final decryptedText = utf8.decode(decryptedBytes);
    debugPrint('Decrypted text: $decryptedText');
    return decryptedText;
  } catch (e, stackTrace) {
    debugPrint('Decryption error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}

Future<bool> validateSignature(
    Map<String, dynamic> data, String resHashKey) async {
  debugPrint("validateSignature called");

  String signatureString = data["payInstrument"]["merchDetails"]["merchId"]
      .toString() +
      data["payInstrument"]["payDetails"]["atomTxnId"].toString() +
      data['payInstrument']['merchDetails']['merchTxnId'].toString() +
      data['payInstrument']['payDetails']['totalAmount'].toStringAsFixed(2) +
      data['payInstrument']['responseDetails']['statusCode'].toString() +
      data['payInstrument']['payModeSpecificData']['subChannel'][0].toString() +
      data['payInstrument']['payModeSpecificData']['bankDetails']['bankTxnId']
          .toString();

  var bytes = utf8.encode(signatureString);
  var key = utf8.encode(resHashKey);

  final hmac = Hmac.sha512();
  final secretKey = SecretKey(key);
  final mac = await hmac.calculateMac(bytes, secretKey: secretKey);

  var genSig =
  mac.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  if (data['payInstrument']['payDetails']['signature'] == genSig) {
    print("ignaure matched");
    return true;
  } else {
    print("signaure does not matched");
    return false;
  }
}

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  String createOrderId = ""; //optional
  String productId = ""; //optional

  bool isButtonDisabled = false;
  Timer? _timer;
  int remainingSeconds = 0;

  static const String disableTimeKey = 'pay_button_disabled_time';
  static const int cooldownMinutes = 8;




  bool isLoading = false;
  List fees = [];
  Map<String, dynamic>? studentData;
  Map<String, dynamic>? atomData;
  Map<String, dynamic>? atomSession;
  Set<int> selectedFees = {}; // Track selected fee IDs
  double totalAmount = 0.0;
  List<String> selectedFees1 = [];
  Timer? _statusCheckTimer; // Timer for checking fee status

  @override
  void initState() {
    super.initState();
    fetchAtomDataKey();
    fetchFeesData();
    checkCooldownStatus();
  }

  Future<void> fetchAtomDataKey() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("token: $token");

    final response = await http.get(
      Uri.parse(ApiRoutes.getAtomSettings),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        atomData = data['atom_settings'];
        atomSession = data['session'];

        print('Atom data : $atomData');
        print('atomSession : $atomSession');
        isLoading = false;
      });
    } else {
      // _showLoginDialog();
    }
  }

  Future<void> fetchFeesData() async {
    setState(() {
      isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse(ApiRoutes.getFees),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        fees = data['fees'];
        fetchStudentData();
        isLoading = false;

        print('FEE List : $fees');
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _toggleSelection(int id, double amount) {
    setState(() {
      if (selectedFees1.contains(id.toString())) {
        selectedFees1.remove(id.toString());
        totalAmount -= amount;
      } else {
        selectedFees1.add(id.toString());
        totalAmount += amount;
      }
    });
  }

  Future<void> fetchStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    if (token == null) {
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.getProfile),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        studentData = data['student'];
        isLoading = false;
        print(studentData);
      });
    } else {}
  }

  Future<void> orderCreate(BuildContext context) async {
    showLoadingDialog(context);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    final url = Uri.parse(ApiRoutes.orderCreate);

    Map<String, dynamic> body = {
      "fee_ids": selectedFees1 ?? [],
      "student_id": studentData?['student_id'].toString(),
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // Adding token here
        },
        body: jsonEncode(body),
      );


      if (response.statusCode == 200) {
        print("Success: ${response.body}");
        Map<String, dynamic> data = jsonDecode(response.body);

        setState(() {
          createOrderId = data["order_id"]; // ✅ Correct assignment
          productId = data["product_id"]; // ✅ Correct assignment
          print('OrderId: $createOrderId');
          print('productId: $productId');
        });

        initiatePayment();

        startStatusCheck(); // Start checking status after payment initiation
      } else {
        print("Failed: ${response.statusCode}, Response: ${response.body}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> orderCreateApi(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    final url = Uri.parse(ApiRoutes.atompay);

    Map<String, dynamic> body = {
      "fee_ids": selectedFees1 ?? [],
      "order_id": createOrderId,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token", // Adding token here
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print("Success: ${response.body}");

        Map<String, dynamic> data = jsonDecode(response.body);
        _showPaymentSuccessDialog(context);
        fetchFeesData();

        setState(() {
          print('Susses: $data');
        });
      } else {
        print("Failed: ${response.statusCode}, Response: ${response.body}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void _refresh() {
    setState(() {
      orderCreateApi(context);
    });
  }

  void _showPaymentSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 10),
                Text(
                  'Payment Successful',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Your payment has been processed successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void startCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(disableTimeKey, currentTime);

    setState(() {
      isButtonDisabled = true;
      remainingSeconds = cooldownMinutes * 60;
    });

    startTimer();
  }

  void startTimer() async {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      setState(() {
        remainingSeconds--;
      });

      if (remainingSeconds <= 0) {
        _timer?.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(disableTimeKey);
        setState(() {
          isButtonDisabled = false;
        });
      }
    });
  }

  void checkCooldownStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final disabledAt = prefs.getInt(disableTimeKey);

    if (disabledAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - disabledAt;
      final elapsedSeconds = diff ~/ 1000;
      final totalCooldown = cooldownMinutes * 60;

      if (elapsedSeconds < totalCooldown) {
        setState(() {
          isButtonDisabled = true;
          remainingSeconds = totalCooldown - elapsedSeconds;
        });
        startTimer();
      } else {
        await prefs.remove(disableTimeKey);
      }
    }
  }

  String formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  // Start the periodic status check when payment is initiated
  void startStatusCheck() {
    _statusCheckTimer?.cancel(); // Cancel any existing timer
    _statusCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      checkFeeStatus();
    });
  }

  // Check the status of selected fees
  Future<void> checkFeeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || selectedFees1.isEmpty) {
      _statusCheckTimer?.cancel(); // Stop timer if no token or no selected fees
      return;
    }

    final response = await http.get(
      Uri.parse(ApiRoutes.getFees), // Assuming this endpoint returns fee data
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List updatedFees = data['fees'];

      // Check if all selected fees are paid
      bool allPaid = selectedFees1.every((feeId) {
        var fee = updatedFees.firstWhere(
              (f) => f['id'].toString() == feeId,
          orElse: () => null,
        );
        return fee != null && fee['pay_status'].toLowerCase() == 'paid';
      });

      if (allPaid) {
        setState(() {
          fees = updatedFees; // Update the fees list
          selectedFees1.clear(); // Clear selected fees
          totalAmount = 0.0; // Reset total amount
        });
        _statusCheckTimer?.cancel(); // Stop the timer
        // _showPaymentSuccessDialog(context); // Show success dialog
      } else {
        setState(() {
          fees = updatedFees; // Update UI with latest fee data
        });
      }
    } else {
      print("Failed to fetch fee status: ${response.statusCode}");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusCheckTimer?.cancel(); // Cancel the status check timer
    super.dispose();
  }

  void _showCooldownDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      // Allow dialog to be dismissed by tapping outside
      builder: (BuildContext context) {
        return _CooldownDialog(remainingSeconds: remainingSeconds);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body:  isLoading
          ? _buildShimmerLoading()
          : Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: fees.length,
                  itemBuilder: (context, index) {
                    String dueDate = fees[index]['due_date'].toString();
                    String monthName = "";
                    if (dueDate.isNotEmpty) {
                      DateTime parsedDate = DateTime.parse(dueDate);
                      monthName = DateFormat('MMMM').format(parsedDate);
                    }

                    return PaymentCard(
                      amount: fees[index]['to_pay_amount'].toString(),
                      status: fees[index]['pay_status'],
                      dueDate: fees[index]['due_date'].toString(),
                      payDate: fees[index]['pay_date'].toString(),
                      id: fees[index]['id'],
                      isSelected: selectedFees1.contains(
                          fees[index]['installment_id'].toString()),
                      onSelect: (bool selected) {
                        _toggleSelection(
                            fees[index]['installment_id'],
                            double.parse(
                                fees[index]['to_pay_amount'].toString()));
                        print(selectedFees1);
                      },
                      month: monthName,
                    );
                  },
                ),
              ),
              if (selectedFees1.isNotEmpty &&
                  atomSession?['payment'].toString() == '1')
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        if (isButtonDisabled) {
                          // Show dialog when timer is running
                          _showCooldownDialog(context);
                        } else {
                          // orderCreate(context);
                          // startCooldown();

                          onPayNow();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 10.sp),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isButtonDisabled
                            ? 'Please wait (${formatDuration(remainingSeconds)})'
                            : 'Pay ₹ ${totalAmount.toString()}',
                        style: GoogleFonts.montserrat(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Center(
      child: CupertinoActivityIndicator(radius: 30,color: Colors.white,),
    );
  }

  Future<void> initiatePayment() async {
    setState(() {
      isLoading = true;
      // currentTxnId = 'Invoice${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    });

    try {
      final String txnDate = DateTime.now().toString().split('.')[0];
      const String amount = "1";
      const String userEmailId = "test.user@atomtech.in";
      const String userContactNo = "8888888888";

      //Json data for sending to atom server
      String jsonData = '{"payInstrument":{"headDetails":{"version":"OTSv1.1","api":"AUTH","platform":"FLASH"},"merchDetails":{"merchId":"${atomData!['login'].toString()}","userId":"712303","password":"${atomData!['password'].toString()}","merchTxnId":"$createOrderId","merchTxnDate":"$txnDate"},"payDetails":{"amount":"${totalAmount.toString()}","product":"$productId","custAccNo":"639827","txnCurrency":"INR"},"custDetails":{"custEmail":"${studentData!['email'].toString()}","custMobile":"${studentData!['contact_no'].toString()}"},  "extras": {"udf1":"${studentData?['student_id'].toString()}","udf2":"$createOrderId","udf3":"$selectedFees1","udf4":"udf4","udf5":"udf5"}}}';

      final String encDataR = await encrypt(jsonData);
      final response = await http.post(
        Uri.parse(authUrl),
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: {
          'encData': encDataR,
          'merchId': '712303',
        },
      );

      if (response.statusCode == 200) {
        debugPrint("Response received: Status code 200");

        final responseData = response.body.split('&');
        debugPrint("Response body split into array: $responseData");

        if (responseData.length > 1) {
          // Extract the encrypted data
          final encDataPart = responseData
              .firstWhere((element) => element.startsWith('encData'));
          final encryptedData = encDataPart.split('=')[1];
          final extractedData = ['encData', encryptedData];
          debugPrint("Extracted encrypted response data: $extractedData");

          try {
            // Decrypt the extracted data
            final decryptedData = await decrypt(extractedData[1]);
            debugPrint("Decrypted data: $decryptedData");

            final jsonResponse = json.decode(decryptedData);
            debugPrint("JSON response: $jsonResponse");
            hideLoadingDialog(context);


            if (jsonResponse['responseDetails']['txnStatusCode'] == 'OTS0000') {
              setState(() {
                atomTokenId = jsonResponse['atomTokenId'].toString();

                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PaymentWebView(
                          atomTokenId:
                          jsonResponse['atomTokenId'].toString(),
                          merchId: '712303',
                          currentTxnId: createOrderId,
                          onReturn: _refresh,
                          userEmail: studentData!['email'].toString(),
                          userContact:
                          studentData!['contact_no'].toString(),
                        )));
                isLoading = false;
                // ignore: prefer_interpolation_to_compose_strings
                debugPrint("Transaction Status Code: " +
                    jsonResponse['responseDetails']['txnStatusCode']);
              });
            } else {
              debugPrint("Error: txnStatusCode is not 'OTS0000'");
              throw Exception('Payment initialization failed');
            }
          } catch (e) {
            debugPrint("Decryption failed: $e");
            throw Exception('Error during decryption: $e');
          }
        } else {
          debugPrint("Error: Invalid response data format");
          throw Exception('Invalid response data format');
        }
      } else {
        debugPrint(
            "Error: Failed to connect to the server. Status code: ${response.statusCode}");
        throw Exception('Failed to connect to the server');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showError('Payment initialization failed: $e');
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // User manually dialog close na kar sake
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 15.sp),
              Text("Please wait...")
            ],
          ),
        );
      },
    );
  }

  void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }



  Future<bool> showPremiumTermsDialog(BuildContext context) async {
    bool isChecked = false;
    bool showError = false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              backgroundColor: Colors.black,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: 1,
                      )
                    ],
                  ),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // TITLE
                      Center(
                        child: Text(
                          "Terms & Conditions",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // SCROLLABLE AREA
                      Container(
                        height: 330,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            overscroll: true,
                            scrollbars: true,
                          ),
                          child: SingleChildScrollView(
                            // physics: const BouncingScrollPhysics(),
                            child: Text(
                              AppStrings.termsText,
                              textAlign: TextAlign.justify,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 5),

                      // CHECKBOX
                      Row(
                        children: [
                          Checkbox(
                            value: isChecked,
                            activeColor: Colors.green,
                            checkColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            onChanged: (val) {
                              setState(() {
                                isChecked = val!;
                                showError = false; // checkbox tick hote hi error hata do
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              "I have read & agree to the Terms & Conditions ",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13.5,
                              ),
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 5),

// ----------------------
// INLINE ERROR MESSAGE
// ----------------------
                      if (showError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            "⚠️ Please accept Terms & Conditions",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      const SizedBox(height: 6),

// BUTTON ROW
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (!isChecked) {
                                setState(() {
                                  showError = true; // yahi par error dikhana hai
                                });
                                return;
                              }

                              Navigator.pop(context, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Accept & Continue",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ) ??
        false;
  }

  void onPayNow() async {
    bool accepted = await showPremiumTermsDialog(context);

    if (accepted) {
      orderCreate(context);
      startCooldown();
    }
  }

}

class PaymentCard extends StatelessWidget {
  final String amount;
  final String status;
  final String dueDate;
  final String payDate;
  final String month;
  final int id;
  final bool isSelected;
  final ValueChanged<bool> onSelect;

  PaymentCard({
    required this.amount,
    required this.status,
    required this.dueDate,
    required this.payDate,
    required this.id,
    required this.isSelected,
    required this.onSelect,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: EdgeInsets.all(5),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 50.sp,
              width: 50.sp,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${month.substring(0, 3).toUpperCase()}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.sp), // Optional styling
                    ),
                    Text(
                      status.toLowerCase() == 'paid' ? 'Paid' : 'Due',
                      style: GoogleFonts.montserrat(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w700,
                        color: status.toLowerCase() == 'paid'
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "₹$amount",
              style: GoogleFonts.montserrat(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Text(
          status.toLowerCase() == 'paid'
              ? (payDate.length >= 10 ? payDate.substring(0, 10) : payDate)
              : '$dueDate',
          style: GoogleFonts.montserrat(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: status.toLowerCase() == 'paid' ? Colors.green : Colors.red,
          ),
        ),
        trailing: status.toLowerCase() == 'paid'
            ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.print),
              onPressed: () async {
                final Uri uri = Uri.parse('${ApiRoutes.downloadUrl}$id');
                try {
                  if (!await launchUrl(uri,
                      mode: LaunchMode.externalApplication)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open URL')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            ),
            Checkbox(
              onChanged: (bool? value) {
                if (value != null) {}
              },
              value: true,
              activeColor: Colors.green,
            ),
          ],
        )
            : Checkbox(
          value: isSelected,
          onChanged: (bool? value) {
            if (value != null) {
              onSelect(value);
            }
          },
        ),
      ),
    );
  }
}

class _CooldownDialog extends StatefulWidget {
  final int remainingSeconds;

  const _CooldownDialog({required this.remainingSeconds});

  @override
  _CooldownDialogState createState() => _CooldownDialogState();
}

class _CooldownDialogState extends State<_CooldownDialog> {
  late int _currentSeconds;
  Timer? _dialogTimer;

  @override
  void initState() {
    super.initState();
    _currentSeconds = widget.remainingSeconds;
    _startTimer();
  }

  void _startTimer() {
    _dialogTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentSeconds > 0) {
        setState(() {
          _currentSeconds--;
        });
      } else {
        _dialogTimer?.cancel();
        Navigator.pop(
            context); // Automatically close the dialog when time is up
      }
    });
  }

  @override
  void dispose() {
    _dialogTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      title: Text(
        'Payment on Cooldown',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color: Colors.orange,
            size: 50.sp,
          ),
          SizedBox(height: 10.sp),
          Text(
            'Please wait for ${_formatDuration(_currentSeconds)} before you can make another payment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the dialog manually
          },
          child: Text(
            'OK',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ),
      ],
    );
  }
}



class PaymentWebView extends StatefulWidget {
  final String atomTokenId;
  final String merchId;
  final String currentTxnId;
  final VoidCallback onReturn;
  final String userEmail;
  final String userContact;

  const PaymentWebView({
    required this.atomTokenId,
    required this.merchId,
    required this.currentTxnId,
    required this.onReturn,
    required this.userEmail,
    required this.userContact,
    super.key,
  });

  @override
  State createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  double progress = 0;
  late InAppWebViewController webViewController;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _handleBackButtonAction(context),
      child: Scaffold(
        backgroundColor: HexColor('#3c2365'),
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 40.sp),
              child: InAppWebView(
                  initialData: InAppWebViewInitialData(
                    data: '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://psa.atomtech.in/staticdata/ots/js/atomcheckout.js"></script>
      </head>
      <body>
      <script>
          function initPayment() {
            const options = {
              "atomTokenId": "${widget.atomTokenId}",
              "merchId": "${widget.merchId}",
              "custEmail": "${widget.userEmail}",
              "custMobile": "${widget.userContact}",
              "returnUrl": "https://payment.atomtech.in/mobilesdk/param",
              "userAgent": "mobile_webView"
            };
            new AtomPaynetz(options, 'uat');
          }
          window.onload = initPayment;
        </script>
      </body>
      </html>
      ''',
                  ),
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    debugPrint("shouldOverrideUrlLoading called");
                    var uri = navigationAction.request.url!;

                    if (["upi", "tez", "gpay", "phonepe", "paytmmp", "credpay"]
                        .any(uri.scheme.contains)) {
                      debugPrint("UPI URL detected");
                      await launchUrl(uri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                  ),

                  onLoadStop: (controller, url) async {
                    print("onLoadStop");
                    print(url);
                    setState(() {
                      progress = 1.0;
                    });

                    if (url != null) {
                      // Check for returnUrl
                      if (url.toString().contains("returnUrl")) {
                        print("returnUrl detected");
                        _closeWebView(context, "Return URL Called");
                        return; // Exit after closing WebView
                      }

                      // Existing logic for /mobilesdk/param
                      if (url.toString().contains("/mobilesdk/param")) {
                        print("/mobilesdk/param detected");

                        // New code to evaluate JavaScript and get the response
                        final String response = await controller.evaluateJavascript(
                            source: "document.getElementsByTagName('h5')[0].innerHTML");
                        debugPrint("HTML response : $response");

                        final split = response.trim().split('|');
                        final Map<int, String> values = {
                          for (int i = 0; i < split.length; i++) i: split[i]
                        };

                        var transactionResult = "";

                        if (response.trim().contains("cancelTransaction")) {
                          transactionResult = "Transaction Cancelled!";
                        } else {
                          final splitTwo = values[1]!.split('=');
                          print("encData value");
                          debugPrint(splitTwo[1].toString());

                          final decryptedResponseData = await decrypt(splitTwo[1].toString());
                          debugPrint('Decrypted response data: $decryptedResponseData');

                          Map<String, dynamic> jsonInput = jsonDecode(decryptedResponseData);
                          debugPrint("Reading full response: $jsonInput");

                          var checkFinalTransaction = await validateSignature(jsonInput, resHashKey);
                          debugPrint("Signature matched: $checkFinalTransaction");

                          if (checkFinalTransaction) {
                            print("Signature is valid");
                            if (jsonInput["payInstrument"]["responseDetails"]["statusCode"] == 'OTS0000') {
                              debugPrint("Transaction success and close");
                              transactionResult = "Transaction Success";
                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   SnackBar(
                              //     content: Text("Transaction Successful!"),
                              //     duration: Duration(seconds: 3),
                              //     backgroundColor: Colors.green,
                              //   ),
                              // );
                            } else {
                              debugPrint("Transaction failed");
                              transactionResult = "Transaction Failed";
                            }
                          } else {
                            debugPrint("Signature mismatched");
                            transactionResult = "Signature Failed";
                          }
                        }
                        _closeWebView(context, transactionResult);
                      }
                    }
                  }),
              // onLoadStop: (controller, url) async {
              //           print("onLoadStop");
              //           print(url);
              //           setState(() {
              //             progress = 1.0;
              //           });
              //
              //           if (url != null && url.toString().contains("/mobilesdk/param")) {
              //             print("/mobilesdk/param detected");
              //             _closeWebView(context, "WebView Closed");
              //           }
              //         },
            ),

          ],
        ),
      ),
    );
  }

  void _closeWebView(BuildContext context, String transactionResult) {
    // debugPrint("Closing web");
    // debugPrint("result: $transactionResult");
    if (!mounted) return;

    Navigator.of(context).pop();

    // Check transaction result and show appropriate dialog
    if (transactionResult == 'Transaction Success') {
      // _showPaymentSuccessDialog(context);
      Future.delayed(Duration(seconds: 5), () {
        widget.onReturn();
      });
    } else if (transactionResult == 'Transaction Cancelled!') {
      _showPaymentCanceledDialog(context);
      // Fluttertoast.showToast(
      //   msg: "Transaction Cancelled",
      //   toastLength: Toast.LENGTH_LONG,
      //   gravity: ToastGravity.CENTER,
      //   timeInSecForIosWeb: 1,
      //   backgroundColor: Colors.red,
      //   textColor: Colors.white,
      //   fontSize: 16.0,
      // );
    } else {
      // Fluttertoast.showToast(
      //   msg: "Error",
      //   toastLength: Toast.LENGTH_LONG,
      //   gravity: ToastGravity.CENTER,
      //   timeInSecForIosWeb: 1,
      //   backgroundColor: Colors.red,
      //   textColor: Colors.white,
      //   fontSize: 16.0,
      // );
    }


  }

  Future<bool> _handleBackButtonAction(BuildContext context) async {
    debugPrint("_handleBackButtonAction called");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Do you want to exit the payment?'),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop();
              _showPaymentCanceledDialog(context);
              // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              //   content: Text("Transaction Status = Transaction cancelled"),
              // ));
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return Future.value(true);
  }

  void _showPaymentSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 10),
                Text(
                  'Payment Successful',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Your payment has been processed successfully!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentCanceledDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Icon(
                  Icons.cancel_rounded,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 10),
                Text(
                  'Transaction Cancelled',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Your transaction has been cancelled.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  ),
                  onPressed: () {

                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'OK',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }


}