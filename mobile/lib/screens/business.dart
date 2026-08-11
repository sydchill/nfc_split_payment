import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// ---------------------------------------------------------------------------
// Business: amount keypad
// ---------------------------------------------------------------------------

class BizAmountScreen extends StatelessWidget {
  const BizAmountScreen({super.key});

  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', 'back'];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BackChevronRow(title: 'New payment', onBack: () => app.go(app.homeScreen)),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Amount to charge',
                        style: TextStyle(
                            fontSize: 13, color: T.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(app.chargeDisplay,
                        style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -2,
                            color: app.canCharge ? T.ink : T.chargeGhost)),
                    const SizedBox(height: 4),
                    const Text('Fig & Vine Café',
                        style: TextStyle(fontSize: 13, color: T.faint)),
                  ],
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.75,
              children: [
                for (final k in _keys)
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => app.press(k),
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: k == 'back'
                            ? const StrokeIcon(AppIcons.backspace,
                                size: 26, color: T.ink, strokeWidth: 1.8)
                            : Text(k,
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    color: T.ink)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TButton(
              label: 'Charge ${app.chargeDisplay}',
              bg: app.canCharge ? T.indigo : T.disabledBg,
              fg: app.canCharge ? Colors.white : T.disabledFg,
              onTap: app.canCharge ? app.doCharge : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Business: tap to pay
// ---------------------------------------------------------------------------

class BizTapScreen extends StatelessWidget {
  const BizTapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [T.ink, Color(0xFF262F5C)]),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: app.toBizAmount,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            if (app.bizWaiting)
                              Ripples(
                                  size: 200,
                                  color: Colors.white.withValues(alpha: .3),
                                  count: 3,
                                  period: const Duration(milliseconds: 2200)),
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: Center(
                                child: app.bizProcessing
                                    ? const Spinner()
                                    : const StrokeIcon(AppIcons.wavesWide,
                                        size: 48, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(app.chargeDisplay,
                          style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -1)),
                      const SizedBox(height: 8),
                      Text(app.bizTapMsg,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: .75))),
                    ],
                  ),
                ),
              ),
              if (app.bizWaiting)
                Row(
                  children: [
                    Expanded(
                      child: TButton(
                        label: 'Tap a card',
                        height: 54,
                        radius: 15,
                        fontSize: 15,
                        bg: Colors.white.withValues(alpha: .14),
                        onTap: () => app.sim(PayMethod.card),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TButton(
                        label: 'Tap a phone',
                        height: 54,
                        radius: 15,
                        fontSize: 15,
                        bg: Colors.white,
                        fg: T.indigoDeep,
                        onTap: () => app.sim(PayMethod.phone),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Business: approved
// ---------------------------------------------------------------------------

class BizApprovedScreen extends StatelessWidget {
  const BizApprovedScreen({super.key});

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
              const Text('Approved',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -.5)),
              const SizedBox(height: 6),
              Text(app.chargeDisplay,
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.w700, color: T.indigo)),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: T.border),
                ),
                child: Column(
                  children: [
                    _row('Method', app.bizMethodLabel, divider: true),
                    _row('Card', app.chargeMaskedPan, divider: true),
                    _row('Reference', app.chargeReference),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                      child: TButton(
                          label: 'New sale', fontSize: 16, onTap: app.toBizAmount)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TButton(
                      label: 'Done',
                      fontSize: 16,
                      bg: Colors.white,
                      fg: T.ink,
                      border: const BorderSide(color: T.border, width: 1.5),
                      onTap: () => app.go(AppScreen.homeBiz),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool divider = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: divider
          ? const BoxDecoration(border: Border(bottom: BorderSide(color: T.divider)))
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: T.muted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: T.ink)),
        ],
      ),
    );
  }
}
