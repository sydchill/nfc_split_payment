import 'package:flutter/material.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'shell.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Patela: env=${ApiConfig.environment} api=${ApiConfig.baseUrl}');
  runApp(PatelaApp(api: ApiClient()));
}

class PatelaApp extends StatefulWidget {
  const PatelaApp({super.key, required this.api});

  final ApiClient api;

  @override
  State<PatelaApp> createState() => _PatelaAppState();
}

class _PatelaAppState extends State<PatelaApp> {
  late final AppState _state = AppState(api: widget.api);

  @override
  void initState() {
    super.initState();
    // Sign straight back in if a saved session is still valid.
    _state.restoreSession();
  }

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
        title: 'Patela',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Poppins',
          scaffoldBackgroundColor: T.cream,
          colorScheme: ColorScheme.fromSeed(seedColor: T.indigo),
          splashFactory: InkRipple.splashFactory,
        ),
        home: const PatelaShell(),
      ),
    );
  }
}
