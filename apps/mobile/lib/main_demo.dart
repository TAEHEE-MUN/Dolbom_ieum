import 'package:flutter/material.dart';

import 'demo/app.dart';
import 'demo/model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const defined = String.fromEnvironment('DEMO_SCREEN', defaultValue: 'login');
  final requested = Uri.base.queryParameters['screen'] ?? defined;
  final initial = DemoScreen.values.firstWhere(
    (s) => s.name == requested,
    orElse: () => DemoScreen.login,
  );
  runApp(DemoApp(initialScreen: initial));
}
