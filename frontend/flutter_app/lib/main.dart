import 'package:flutter/material.dart';

import 'api_client.dart';
import 'home_screen.dart';
import 'vcs_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final baseUrl = await ApiClient.loadBaseUrl();
  runApp(VoiceCloneShieldApp(baseUrl: baseUrl));
}

class VoiceCloneShieldApp extends StatelessWidget {
  const VoiceCloneShieldApp({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Clone Shield',
      debugShowCheckedModeBanner: false,
      theme: VcsTheme.dark(),
      home: HomeScreen(api: ApiClient(baseUrl)),
    );
  }
}
