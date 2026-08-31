import 'package:flutter/material.dart';

Widget brokenOverflowWidget() {
  return Center(
    child: SizedBox(
      width: 100,
      child: Row(
        children: [
          Container(width: 80, height: 20, color: Colors.red),
          Container(width: 80, height: 20, color: Colors.blue),
        ],
      ),
    ),
  );
}

Widget brokenRtlWidget() {
  return Scaffold(
    body: Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Container(width: 200, height: 40, color: Colors.green),
        ],
      ),
    ),
  );
}
