import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shell.dart';
import 'state.dart';
import 'supabase_config.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }
  runApp(const TandemApp());
}

class TandemApp extends StatefulWidget {
  const TandemApp({super.key});

  @override
  State<TandemApp> createState() => _TandemAppState();
}

class _TandemAppState extends State<TandemApp> {
  final AppState _state = AppState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _state,
      child: MaterialApp(
        title: 'Tandem',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Poppins',
          scaffoldBackgroundColor: T.cream,
          colorScheme: ColorScheme.fromSeed(seedColor: T.indigo),
          splashFactory: InkRipple.splashFactory,
        ),
        home: const TandemShell(),
      ),
    );
  }
}
