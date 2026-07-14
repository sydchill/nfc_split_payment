import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// ---------------------------------------------------------------------------
// Split: set amounts
// ---------------------------------------------------------------------------

class SplitAmountScreen extends StatelessWidget {
  const SplitAmountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackChevronRow(title: 'Split the bill', onBack: () => app.go(app.homeScreen)),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: T.border),
              ),
              child: Column(
                children: [
                  const Text('You paid at The Fig Tree',
                      style: TextStyle(
                          fontSize: 13, color: T.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(fmt(app.total),
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: T.ink,
                          letterSpacing: -1)),
                  const SizedBox(height: 2),
                  const Text('Total bill · 4 people',
                      style: TextStyle(fontSize: 13, color: T.muted)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Who owes what',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
                Material(
                  color: T.peachSoft,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: app.splitEven,
                    borderRadius: BorderRadius.circular(9),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Text('Split evenly',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: T.indigoDeep)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _shareRow(
                      avatar: const Avatar(initials: 'AR', color: T.indigo),
                      name: 'You',
                      sub: 'Your share of the bill',
                      trailing: Text(fmt(app.yourShare),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600, color: T.ink)),
                    ),
                    for (var i = 0; i < app.friends.length; i++)
                      _shareRow(
                        avatar: Avatar(
                            initials: app.friends[i].initials,
                            color: app.friends[i].color),
                        name: app.friends[i].name,
                        sub: 'owes you',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StepBtn(label: '−', onTap: () => app.adj(i, -1)),
                            SizedBox(
                              width: 78,
                              child: Text(
                                fmt(app.friends[i].amount),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: T.ink),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _StepBtn(label: '+', onTap: () => app.adj(i, 1)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Collecting from friends',
                      style: TextStyle(
                          fontSize: 14, color: T.muted, fontWeight: FontWeight.w600)),
                  Text(fmt(app.owedTotal),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: T.indigo)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TButton(
                label: 'Start collecting',
                onTap: () => app.go(AppScreen.splitCollect)),
          ],
        ),
      ),
    );
  }

  Widget _shareRow({
    required Widget avatar,
    required String name,
    required String sub,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: T.divider))),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: T.ink)),
                Text(sub, style: const TextStyle(fontSize: 12, color: T.muted)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: T.border, width: 1.5)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: T.ink, height: 1)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Split: collect
// ---------------------------------------------------------------------------

class SplitCollectScreen extends StatelessWidget {
  const SplitCollectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pct = app.owedTotal > 0 ? app.collected / app.owedTotal : 0.0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackChevronRow(
                title: 'Collecting', onBack: () => app.go(AppScreen.splitAmount)),
            const SizedBox(height: 18),
            Center(
              child: Column(
                children: [
                  ProgressRing(
                    progress: pct,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(fmt(app.collected),
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: T.ink)),
                        const SizedBox(height: 2),
                        Text('of ${fmt(app.owedTotal)}',
                            style: const TextStyle(fontSize: 12, color: T.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    app.allPaid
                        ? 'All settled 🎉'
                        : '${app.paidCount} of ${app.friends.length} paid',
                    style: const TextStyle(
                        fontSize: 14, color: T.muted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < app.friends.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _CollectCard(friend: app.friends[i], onTap: () => app.startTap(i)),
                    ],
                  ],
                ),
              ),
            ),
            if (app.allPaid) ...[
              const SizedBox(height: 20),
              TButton(
                  label: 'Bill settled — view summary',
                  onTap: () => app.go(AppScreen.splitDone)),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 18, left: 20, right: 20),
                child: Text(
                  'Each friend holds their phone to yours and confirms — no app switching, no cash.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: T.faint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CollectCard extends StatelessWidget {
  const _CollectCard({required this.friend, required this.onTap});

  final Friend friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.border),
      ),
      child: Row(
        children: [
          Avatar(initials: friend.initials, color: friend.color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: T.ink)),
                Text(fmt(friend.amount),
                    style: const TextStyle(fontSize: 13, color: T.muted)),
              ],
            ),
          ),
          if (friend.paid)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StrokeIcon(AppIcons.check, size: 20, color: T.indigo, strokeWidth: 2.5),
                SizedBox(width: 6),
                Text('Paid',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: T.indigo)),
              ],
            )
          else
            Material(
              color: T.ink,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(11),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StrokeIcon(AppIcons.waves,
                          size: 14, color: Colors.white, strokeWidth: 2.4),
                      SizedBox(width: 6),
                      Text('Tap to pay',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Split: done
// ---------------------------------------------------------------------------

class SplitDoneScreen extends StatelessWidget {
  const SplitDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [T.cream, T.peachSoft]),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              PopIn(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration:
                      const BoxDecoration(color: T.indigo, shape: BoxShape.circle),
                  child: const Center(
                      child: StrokeIcon(AppIcons.check,
                          size: 48, color: Colors.white, strokeWidth: 2.6)),
                ),
              ),
              const SizedBox(height: 24),
              const Text("You're all settled",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -.5)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text.rich(
                  TextSpan(
                    text: 'Collected ',
                    style: const TextStyle(
                        fontSize: 15, color: T.settledSub, height: 1.5),
                    children: [
                      TextSpan(
                          text: fmt(app.owedTotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: T.indigo)),
                      const TextSpan(text: ' from 3 friends for The Fig Tree.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: T.border),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < app.friends.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: i < app.friends.length - 1
                              ? const Border(bottom: BorderSide(color: T.divider))
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(app.friends[i].name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: T.ink)),
                            Text('${fmt(app.friends[i].amount)} · paid',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: T.indigo)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child:
                    TButton(label: 'Done', bg: T.ink, onTap: () => app.go(app.homeScreen)),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tap-to-pay overlay (friend paying their share)
// ---------------------------------------------------------------------------

class TapOverlay extends StatelessWidget {
  const TapOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final friend = app.tapFriend;
    if (friend == null) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: app.cancelTap,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(color: const Color(0xFF0B0D10).withValues(alpha: .55)),
          ),
        ),
        if (app.tapStage == TapStage.searching) _Searching(friend: friend),
        if (app.tapStage == TapStage.sheet) _WalletSheet(app: app, friend: friend),
        if (app.tapStage == TapStage.processing)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spinner(size: 56, strokeWidth: 5),
                const SizedBox(height: 22),
                Text('Sending ${fmt(friend.amount)}…',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Ripples(
                      size: 220,
                      color: Colors.white.withValues(alpha: .35),
                      count: 3,
                      period: const Duration(milliseconds: 2000)),
                  FloatY(
                    child: Avatar(
                        initials: friend.initials,
                        color: friend.color,
                        size: 96,
                        fontSize: 30),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text('Hold phones together',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                '${friend.firstName} is holding their phone to yours to pay ${fmt(friend.amount)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: .7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletSheet extends StatelessWidget {
  const _WalletSheet({required this.app, required this.friend});

  final AppState app;
  final Friend friend;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SheetIn(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                      color: T.sheetHandle, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (app.payMethodLabel == 'Apple Pay')
                      const Icon(Icons.apple, size: 24, color: T.ink)
                    else
                      const GoogleLogo(size: 22),
                    const SizedBox(width: 10),
                    Text(app.payMethodLabel,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
                    const Spacer(),
                    GestureDetector(
                      onTap: app.cancelTap,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                            color: T.sheetClose, shape: BoxShape.circle),
                        child: const Center(
                            child: StrokeIcon(AppIcons.close,
                                size: 13, color: T.muted, strokeWidth: 2.6)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [T.ink, T.heroInkEnd]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${friend.firstName}'s card",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: .6))),
                          const SizedBox(height: 4),
                          const Text('•••• 8842',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 1)),
                        ],
                      ),
                      Container(
                        width: 34,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFE8B94A), Color(0xFFC9932B)]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pay Alex Rivera',
                              style: TextStyle(fontSize: 13, color: T.muted)),
                          Text('The Fig Tree · split',
                              style: TextStyle(fontSize: 12, color: T.faint)),
                        ],
                      ),
                      Text(fmt(friend.amount),
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: T.ink)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: TButton(
                    bg: T.ink,
                    onTap: app.confirmPay,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StrokeIcon(AppIcons.lock, size: 20, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Confirm with Face ID',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
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
