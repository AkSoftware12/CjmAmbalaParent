import 'package:flutter/material.dart';


class  PrimaryCircularProgressWidget extends StatelessWidget {
  const PrimaryCircularProgressWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Colors.purple,
      ), // Show progress bar here
    );
  }
}
