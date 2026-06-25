import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() => runApp(const NetMeterApp());

class NetMeterApp extends StatelessWidget {
  const NetMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Android Network Meter',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      locale: const Locale('fa'),
      home: const Directionality(textDirection: TextDirection.rtl, child: HomePage()),
    );
  }
}
