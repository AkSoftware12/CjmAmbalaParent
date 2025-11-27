import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomHtmlView extends StatelessWidget {
  final String html;

  const CustomHtmlView({super.key, required this.html});

  @override
  Widget build(BuildContext context) {
    final widgets = _parseHtml(html);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

/// Parse HTML sequentially
List<Widget> _parseHtml(String html) {
  final widgets = <Widget>[];

  // Regex for <p>, <ul>, <h4>
  final regex = RegExp(
      r"(<p>[\s\S]*?<\/p>|<ul>[\s\S]*?<\/ul>|<h4>[\s\S]*?<\/h4>)",
      caseSensitive: false);

  int lastIndex = 0;

  for (final match in regex.allMatches(html)) {
    // Add plain text (if any) before tag
    if (match.start > lastIndex) {
      final plainText = html.substring(lastIndex, match.start).trim();
      if (plainText.isNotEmpty) {
        widgets.add(_buildRichText(plainText));
      }
    }

    final tag = match.group(0)!;

    if (tag.startsWith("<p>")) {
      final content = tag.replaceAll(RegExp(r"<\/?p>"), "");
      widgets.add(_buildRichText(content));
    } else if (tag.startsWith("<h4>")) {
      final content = tag
          .replaceAll(RegExp(r"<\/?h4>"), "")
          .replaceAll("<strong>", "")
          .replaceAll("</strong>", "");
      widgets.add(Text(
        content,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ));
    } else if (tag.startsWith("<ul>")) {
      final liRegex = RegExp(r"<li>([\s\S]*?)<\/li>");
      final items = liRegex.allMatches(tag);
      widgets.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((li) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("• ",
                  style: TextStyle(fontSize: 20.sp, color: Colors.black)),
              Expanded(
                child: _buildRichText(li.group(1)!),
              ),
            ],
          );
        }).toList(),
      ));
    }

    lastIndex = match.end;
  }

  // Add remaining plain text after last tag
  if (lastIndex < html.length) {
    final plainText = html.substring(lastIndex).trim();
    if (plainText.isNotEmpty) {
      widgets.add(_buildRichText(plainText));
    }
  }

  return widgets;
}

/// Parse inline tags like <strong>
Widget _buildRichText(String text) {
  final spans = <TextSpan>[];
  final regex = RegExp(r"<strong>(.*?)<\/strong>");
  int lastIndex = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(TextSpan(
        text: text.substring(lastIndex, match.start),
        style: TextStyle(color: Colors.black, fontSize: 12.sp),
      ));
    }
    spans.add(TextSpan(
      text: match.group(1),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black,
        fontSize: 12.sp,
      ),
    ));
    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastIndex),
      style: TextStyle(color: Colors.black, fontSize: 12.sp),
    ));
  }

  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4.sp, horizontal: 0.sp),
    child: RichText(text: TextSpan(children: spans)),
  );
}
