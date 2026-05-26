import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'firebase_options.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Correct Firebase initialization for ALL platforms
  if (kIsWeb) {
    // Web MUST use explicit options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.web,
    );
  } else {
    // Mobile / Desktop uses native config files
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CASC Admin Panel',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
