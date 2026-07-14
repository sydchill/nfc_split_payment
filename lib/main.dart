import 'package:flutter/material.dart';

import 'shell.dart';
import 'state.dart';
import 'theme.dart';

void main() => runApp(const TandemApp());

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
