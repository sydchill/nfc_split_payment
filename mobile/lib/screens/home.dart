import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart' as theme;
import '../widgets.dart';

typedef T = theme.T;

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.eyebrow,
    required this.title,
    required this.avatar,
    required this.onLogout,
  });

  final String eyebrow;
  final String title;
  final Widget avatar;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow,
                  style: const TextStyle(
                      fontSize: 14, color: T.muted, fontWeight: FontWeight.w600)),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -.4)),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: T.border, width: 1.5)),
          child: InkWell(
            onTap: onLogout,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(child: StrokeIcon(AppIcons.logout, size: 20, color: T.muted)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        avatar,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
        GestureDetector(
          onTap: onSeeAll,
          child: const Text('See all',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.indigo)),
        ),
      ],
    );
  }
}

/// Compact inline hint used under the home "recent" headers when empty.
class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(text,
          style: const TextStyle(fontSize: 14, color: T.muted, height: 1.4)),
    );
  }
}

// ---------------------------------------------------------------------------
// Personal home
// ---------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final recent = app.recentActivity;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHeader(
              eyebrow: 'Good evening',
              title: app.displayName,
              avatar: Avatar(initials: app.initials, color: T.indigo, fontSize: 16),
              onLogout: app.logout,
            ),
            const SizedBox(height: 18),
            const Pill(
                text: 'Personal account', bg: T.indigoSoft, fg: T.indigo, dot: T.indigo),
            const SizedBox(height: 18),
            _SplitHeroCard(onTap: app.startSplit),
            const SizedBox(height: 26),
            _SectionHeader(
                title: 'Recent activity', onSeeAll: () => app.go(AppScreen.activity)),
            const SizedBox(height: 6),
            if (app.dataLoading && recent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: T.indigo))),
              )
            else if (recent.isEmpty)
              const _RecentEmpty('No activity yet — split a bill and collected payments appear here.')
            else
              for (final t in recent) TxnRow(txn: t, onTap: () => app.openReceipt(t)),
          ],
        ),
      ),
    );
  }
}

class _SplitHeroCard extends StatelessWidget {
  const _SplitHeroCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [T.ink, T.heroInkEnd]),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -36,
                  top: -36,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                        color: T.peach.withValues(alpha: .9), shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  right: 24,
                  bottom: -30,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white.withValues(alpha: .1), width: 1.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                            child:
                                StrokeIcon(AppIcons.split, size: 24, color: Colors.white)),
                      ),
                      const SizedBox(height: 16),
                      const Text('Split a bill',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -.4)),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          'You pay, friends tap their phone or card to pay you back — no app needed.',
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Colors.white.withValues(alpha: .72)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: const Text('Start a split ›',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: T.ink)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Business home
// ---------------------------------------------------------------------------

class HomeBizScreen extends StatelessWidget {
  const HomeBizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sales = app.recentSales;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeHeader(
              eyebrow: 'Signed in as',
              title: app.displayName,
              avatar:
                  Avatar(initials: app.initials, color: T.ink, fontSize: 16, radius: 14),
              onLogout: app.logout,
            ),
            const SizedBox(height: 18),
            const Pill(
                text: 'Business account',
                bg: T.peachBadge,
                fg: T.bizBadgeFg,
                dot: T.bizIcon),
            const SizedBox(height: 18),
            _SalesCard(sales: app.todaySales),
            const SizedBox(height: 18),
            _TakePaymentCard(onTap: app.startCharge),
            const SizedBox(height: 26),
            _SectionHeader(
                title: 'Recent sales', onSeeAll: () => app.go(AppScreen.activity)),
            const SizedBox(height: 6),
            if (app.dataLoading && sales.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: T.indigo))),
              )
            else if (sales.isEmpty)
              const _RecentEmpty('No sales yet — take a payment and it shows up here.')
            else
              for (final t in sales) TxnRow(txn: t, onTap: () => app.openReceipt(t)),
          ],
        ),
      ),
    );
  }
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.sales});

  final SalesSummary sales;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [T.indigo, T.indigoDeep]),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -36,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                    color: T.peach.withValues(alpha: .85), shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's sales",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: .7))),
                  const SizedBox(height: 6),
                  Text(fmt(sales.total),
                      style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -1)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _stat('${sales.count}', 'sales'),
                      const SizedBox(width: 22),
                      _stat(fmt(sales.avg), 'avg. ticket'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .7))),
      ],
    );
  }
}

class _TakePaymentCard extends StatelessWidget {
  const _TakePaymentCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: T.ink,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                    child: StrokeIcon(AppIcons.card, size: 24, color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Take a payment',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('Accept a tapped card or phone',
                        style: TextStyle(
                            fontSize: 13, color: Colors.white.withValues(alpha: .72))),
                  ],
                ),
              ),
              Text('›',
                  style:
                      TextStyle(fontSize: 22, color: Colors.white.withValues(alpha: .8))),
            ],
          ),
        ),
      ),
    );
  }
}
