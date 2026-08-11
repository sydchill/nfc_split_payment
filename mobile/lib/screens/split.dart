import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// ---------------------------------------------------------------------------
// Split: setup (where you paid, total, who's splitting)
// ---------------------------------------------------------------------------

class SplitAmountScreen extends StatefulWidget {
  const SplitAmountScreen({super.key});

  @override
  State<SplitAmountScreen> createState() => _SplitAmountScreenState();
}

class _SplitAmountScreenState extends State<SplitAmountScreen> {
  late final TextEditingController _merchant;
  late final TextEditingController _total;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final app = AppScope.of(context);
    _merchant = TextEditingController(text: app.splitMerchant);
    _total = TextEditingController(
        text: app.splitTotal > 0 ? app.splitTotal.toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _merchant.dispose();
    _total.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final busy = app.dataLoading;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackChevronRow(title: 'Split the bill', onBack: () => app.go(app.homeScreen)),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: T.border),
                      ),
                      child: Column(
                        children: [
                          LabeledField(
                            label: 'Where did you pay?',
                            hint: 'The Fig Tree',
                            controller: _merchant,
                            onChanged: app.setSplitMerchant,
                          ),
                          const SizedBox(height: 14),
                          LabeledField(
                            label: 'Total bill',
                            hint: '0.00',
                            controller: _total,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            onChanged: app.setSplitTotal,
                          ),
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
                        if (app.draft.isNotEmpty)
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
                    // You
                    _row(
                      avatar: Avatar(initials: app.initials, color: T.indigo),
                      name: 'You',
                      sub: 'Your share of the bill',
                      trailing: Text(fmt(app.draftYourShare),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600, color: T.ink)),
                    ),
                    for (var i = 0; i < app.draft.length; i++)
                      _row(
                        avatar: Avatar(
                            initials: app.draft[i].initials, color: app.draft[i].color),
                        name: app.draft[i].name,
                        sub: 'owes you',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StepBtn(label: '−', onTap: () => app.adjustDraft(i, -1)),
                            SizedBox(
                              width: 70,
                              child: Text(fmt(app.draft[i].amount),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: T.ink)),
                            ),
                            const SizedBox(width: 8),
                            _StepBtn(label: '+', onTap: () => app.adjustDraft(i, 1)),
                            const SizedBox(width: 4),
                            _StepBtn(
                                label: '×',
                                muted: true,
                                onTap: () => app.removeFromDraft(app.draft[i].id)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    _AddFriendButton(onTap: () => _showAddFriend(context, app)),
                    if (app.draft.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('Add the friends who are splitting this bill with you.',
                            style: TextStyle(fontSize: 13, color: T.muted, height: 1.4)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Collecting from friends',
                    style:
                        TextStyle(fontSize: 14, color: T.muted, fontWeight: FontWeight.w600)),
                Text(fmt(app.draftOwed),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: T.indigo)),
              ],
            ),
            const SizedBox(height: 12),
            TButton(
              onTap: (app.canStartCollecting && !busy) ? app.startCollecting : null,
              bg: (app.canStartCollecting && !busy) ? T.indigo : T.disabledBg,
              fg: (app.canStartCollecting && !busy) ? Colors.white : T.disabledFg,
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text('Start collecting',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: (app.canStartCollecting && !busy)
                              ? Colors.white
                              : T.disabledFg)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({
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

void _showAddFriend(BuildContext context, AppState app) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AddFriendSheet(app: app),
  );
}

class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet({required this.app});

  final AppState app;

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addNew() async {
    final n = _name.text.trim();
    if (n.isEmpty || _saving) return;
    setState(() => _saving = true);
    await widget.app.createAndAddFriend(n);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final available =
        app.savedFriends.where((f) => !app.draft.any((p) => p.friendId == f.id)).toList();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
          22, 16, 22, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 5,
              decoration:
                  BoxDecoration(color: T.sheetHandle, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Add a friend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: T.ink)),
          const SizedBox(height: 14),
          if (available.isNotEmpty) ...[
            const Text('From your friends',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.muted)),
            const SizedBox(height: 8),
            ...available.map((f) => InkWell(
                  onTap: () {
                    app.addFriendToDraft(f);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Avatar(initials: f.initials, color: f.color, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(f.name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: T.ink)),
                        ),
                        const Text('+ Add',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: T.indigo)),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            const Text('Or add someone new',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.muted)),
            const SizedBox(height: 8),
          ],
          LabeledField(
            label: 'Name',
            hint: 'Maya Chen',
            controller: _name,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addNew(),
          ),
          const SizedBox(height: 16),
          TButton(
            onTap: _saving ? null : _addNew,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Add friend',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AddFriendButton extends StatelessWidget {
  const _AddFriendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: T.border, width: 1.5),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 20, color: T.indigo),
              SizedBox(width: 8),
              Text('Add friend',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T.indigo)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.label, required this.onTap, this.muted = false});

  final String label;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: CircleBorder(side: BorderSide(color: T.border, width: 1.5)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: muted ? T.faint : T.ink,
                    height: 1)),
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
    final bill = app.bill;
    if (bill == null) return const SizedBox.shrink();
    final pct = bill.owedTotal > 0 ? bill.collected / bill.owedTotal : 0.0;
    final n = bill.participants.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackChevronRow(
                title: 'Collecting', onBack: () => app.go(AppScreen.splitAmount)),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text('${bill.merchant} · $n friends',
                  style: const TextStyle(
                      fontSize: 13, color: T.muted, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  ProgressRing(
                    progress: pct,
                    size: 180,
                    strokeWidth: 16,
                    gradient: const [T.indigo, Color(0xFF7A82D8), T.peach, T.indigo],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('collected',
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: .5,
                                fontWeight: FontWeight.w700,
                                color: T.faint)),
                        const SizedBox(height: 2),
                        Text(fmt(bill.collected),
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: T.ink,
                                letterSpacing: -.5,
                                fontFeatures: tabularFigures)),
                        Text('of ${fmt(bill.owedTotal)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: T.muted,
                                fontFeatures: tabularFigures)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StatusPill(bill: bill),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: n,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => StaggerIn(
                  delay: Duration(milliseconds: 60 * i),
                  child: _CollectCard(
                      p: bill.participants[i], onTap: () => app.startTap(i)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (bill.allPaid)
              TButton(
                onTap: () => app.go(AppScreen.splitDone),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View summary',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                    SizedBox(width: 8),
                    Text('→',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: T.border),
                ),
                child: const Row(
                  children: [
                    StrokeIcon(AppIcons.waves, size: 18, color: T.indigo, strokeWidth: 2.2),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Each friend holds their phone to yours and confirms — no cash, no app-switching.',
                        style: TextStyle(fontSize: 12.5, height: 1.35, color: T.muted),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Segmented paid-progress dots + status label.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final done = bill.allPaid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: done ? T.peachSoft : T.indigoSoft,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done)
            const StrokeIcon(AppIcons.check, size: 15, color: T.indigoDeep, strokeWidth: 3)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < bill.participants.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bill.participants[i].paid ? T.indigo : T.ringTrack,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 4),
          Text(
            done
                ? 'All settled'
                : '${bill.paidCount} of ${bill.participants.length} paid',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: T.indigoDeep),
          ),
        ],
      ),
    );
  }
}

class _CollectCard extends StatelessWidget {
  const _CollectCard({required this.p, required this.onTap});

  final Participant p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paid = p.paid;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: paid ? T.indigoSoft : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: paid ? Colors.transparent : T.border),
      ),
      child: Row(
        children: [
          Avatar(initials: p.initials, color: p.color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: T.ink)),
                const SizedBox(height: 1),
                Text(
                  paid ? 'Paid · ${methodLabelFor(p.method)}' : 'owes ${fmt(p.amount)}',
                  style: const TextStyle(
                      fontSize: 12.5, color: T.muted, fontFeatures: tabularFigures),
                ),
              ],
            ),
          ),
          if (paid)
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: T.indigo, shape: BoxShape.circle),
              child: const Center(
                  child: StrokeIcon(AppIcons.check,
                      size: 18, color: Colors.white, strokeWidth: 2.6)),
            )
          else
            PressableScale(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                decoration: BoxDecoration(
                  color: T.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StrokeIcon(AppIcons.waves,
                        size: 14, color: Colors.white, strokeWidth: 2.4),
                    SizedBox(width: 7),
                    Text('Tap to pay',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
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
    final bill = app.bill;
    if (bill == null) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [T.cream, T.peachSoft]),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            children: [
              const SizedBox(height: 20),
              PopIn(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(color: T.indigo, shape: BoxShape.circle),
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
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text.rich(
                  TextSpan(
                    text: 'Collected ',
                    style: const TextStyle(fontSize: 15, color: T.settledSub, height: 1.5),
                    children: [
                      TextSpan(
                          text: fmt(bill.collected),
                          style:
                              const TextStyle(fontWeight: FontWeight.w700, color: T.indigo)),
                      TextSpan(
                          text:
                              ' from ${bill.participants.length} friends for ${bill.merchant}.'),
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
                    for (var i = 0; i < bill.participants.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: i < bill.participants.length - 1
                              ? const Border(bottom: BorderSide(color: T.divider))
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(bill.participants[i].name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: T.ink)),
                            Text('${fmt(bill.participants[i].amount)} · paid',
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
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tap-to-pay overlay (a friend paying their share)
// ---------------------------------------------------------------------------

class TapOverlay extends StatelessWidget {
  const TapOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.tapParticipant;
    if (p == null) return const SizedBox.shrink();
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
        if (app.tapStage == TapStage.searching) _Searching(p: p),
        if (app.tapStage == TapStage.sheet) _WalletSheet(app: app, p: p),
        if (app.tapStage == TapStage.processing)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spinner(size: 56, strokeWidth: 5),
                const SizedBox(height: 22),
                Text('Sending ${fmt(p.amount)}…',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching({required this.p});

  final Participant p;

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
                        initials: p.initials, color: p.color, size: 96, fontSize: 30),
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
                '${p.firstName} is holding their phone to yours to pay ${fmt(p.amount)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, height: 1.5, color: Colors.white.withValues(alpha: .7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletSheet extends StatelessWidget {
  const _WalletSheet({required this.app, required this.p});

  final AppState app;
  final Participant p;

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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                          Text("${p.firstName}'s card",
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pay ${app.displayName}',
                              style: const TextStyle(fontSize: 13, color: T.muted)),
                          Text('${app.bill?.merchant ?? ''} · split',
                              style: const TextStyle(fontSize: 12, color: T.faint)),
                        ],
                      ),
                      Text(fmt(p.amount),
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700, color: T.ink)),
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
