import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class FileOpener {
  static Future<void> openFile(String url) async {
    if (url.endsWith('.jpg') || url.endsWith('.png') || url.endsWith('.jpeg')) {
      await launchUrl(Uri.parse(url)); // Opens in browser
    } else if (url.endsWith('.pdf') || url.endsWith('.xls') || url.endsWith('.xlsx') || url.endsWith('.doc') || url.endsWith('.docx')) {
      await OpenFilex.open(url);
    } else {
      await OpenFilex.open(url); // Open any other file type
    }
  }
}
