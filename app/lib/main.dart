import 'package:flutter/material.dart';

import 'app/boot_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootApp());
}
