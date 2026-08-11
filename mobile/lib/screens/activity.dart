import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final txns = app.transactions;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 4),
              child: Text('Activity',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -.4)),
            ),
            if (app.dataLoading && txns.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: T.indigo)),
              )
            else if (txns.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: AppIcons.bars,
                  title: 'No activity yet',
                  subtitle: 'Payments you collect from splits and sales you take will appear here.',
                ),
              )
            else
              for (final t in txns) TxnRow(txn: t, onTap: () => app.openReceipt(t)),
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
    final Widget avatar = r.isSale
        ? Container(
            width: 64,
            height: 64,
            decoration:
                BoxDecoration(color: T.peachSoft, borderRadius: BorderRadius.circular(16)),
            child: const Center(
                child: StrokeIcon(AppIcons.card, size: 26, color: T.indigo, strokeWidth: 2.2)),
          )
        : Avatar(initials: r.initials, color: r.color, size: 64, fontSize: 22, radius: 16);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BackChevronRow(title: 'Receipt', onBack: app.receiptBack),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  avatar,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: T.peachSoft, borderRadius: BorderRadius.circular(20)),
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
                  _row('Date', r.dateLabel, divider: true),
                  _row('Method', r.methodLabel, divider: true),
                  _row('Reference', r.reference ?? '—'),
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
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink)),
          ),
        ],
      ),
    );
  }
}
