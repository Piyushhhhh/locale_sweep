import 'package:flutter/material.dart';

Widget cleanWidget() {
  return const Center(
    child: SizedBox(
      width: 300,
      child: Row(
        children: [
          Expanded(child: Text('Content that wraps properly within bounds')),
        ],
      ),
    ),
  );
}

Widget cleanRtlSafeWidget() {
  return Scaffold(
    body: Padding(
      padding: const EdgeInsetsDirectional.only(start: 32),
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
