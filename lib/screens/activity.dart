import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Activity',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -.4)),
            ),
            for (final a in AppState.activityAll)
              InkWell(
                onTap: () => app.openReceipt(a),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: T.divider))),
                  child: Row(
                    children: [
                      Avatar(initials: a.initials, color: a.color, radius: 12),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: T.ink)),
                            Text(a.sub,
                                style:
                                    const TextStyle(fontSize: 13, color: T.muted)),
                          ],
                        ),
                      ),
                      Text(a.amountStr,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: a.positive ? T.indigo : T.ink)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final r = app.receipt;
    if (r == null) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BackChevronRow(title: 'Receipt', onBack: app.receiptBack),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Avatar(
                      initials: r.initials,
                      color: r.color,
                      size: 64,
                      fontSize: 22,
                      radius: 16),
                  const SizedBox(height: 14),
                  Text(r.title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
                  const SizedBox(height: 6),
                  Text(r.amountStr,
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: r.positive ? T.indigo : T.ink)),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: T.peachSoft,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StrokeIcon(AppIcons.check,
                            size: 14, color: T.indigoDeep, strokeWidth: 3),
                        SizedBox(width: 6),
                        Text('Completed',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: T.indigoDeep)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: T.border),
              ),
              child: Column(
                children: [
                  _row('Date', r.date, divider: true),
                  _row('Method', r.method, divider: true),
                  _row('Reference', r.ref),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TButton(label: 'Close', bg: T.ink, height: 54, fontSize: 16, onTap: app.receiptBack),
          ],
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
