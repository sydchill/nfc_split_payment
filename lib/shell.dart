import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/activity.dart';
import 'screens/auth.dart';
import 'screens/business.dart';
import 'screens/home.dart' hide T;
import 'screens/split.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class TandemShell extends StatelessWidget {
  const TandemShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final darkChrome = app.screen == AppScreen.onboard1 ||
        app.screen == AppScreen.bizTap ||
        app.tapActive;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkChrome
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: T.cream,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(app.screen),
                      child: _screenFor(app.screen),
                    ),
                  ),
                ),
                if (app.showNav) const _BottomNav(),
              ],
            ),
            if (app.tapActive) const TapOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _screenFor(AppScreen s) {
    switch (s) {
      case AppScreen.onboard1:
        return const OnboardScreen();
      case AppScreen.chooseType:
        return const ChooseTypeScreen();
      case AppScreen.signup:
        return const SignupScreen();
      case AppScreen.signin:
        return const SigninScreen();
      case AppScreen.home:
        return const HomeScreen();
      case AppScreen.homeBiz:
        return const HomeBizScreen();
      case AppScreen.splitAmount:
        return const SplitAmountScreen();
      case AppScreen.splitCollect:
        return const SplitCollectScreen();
      case AppScreen.splitDone:
        return const SplitDoneScreen();
      case AppScreen.bizAmount:
        return const BizAmountScreen();
      case AppScreen.bizTap:
        return const BizTapScreen();
      case AppScreen.bizApproved:
        return const BizApprovedScreen();
      case AppScreen.activity:
        return const ActivityScreen();
      case AppScreen.receipt:
        return const ReceiptScreen();
    }
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final onHome = app.screen == AppScreen.home || app.screen == AppScreen.homeBiz;
    final onActivity = app.screen == AppScreen.activity;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: T.divider)),
      ),
      padding: const EdgeInsets.only(top: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavItem(
              label: 'Home',
              icon: AppIcons.home,
              active: onHome,
              onTap: () => app.go(app.homeScreen),
            ),
            const SizedBox(width: 70),
            _NavItem(
              label: 'Activity',
              icon: AppIcons.bars,
              active: onActivity,
              onTap: () => app.go(AppScreen.activity),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final PathBuilder icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? T.indigo : T.faint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StrokeIcon(icon, size: 24, color: color),
            const SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
