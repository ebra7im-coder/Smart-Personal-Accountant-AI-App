// HomeShell: bottom navigation (الرئيسية، الميزانيات، المحاسب الآلي، التقارير،
// الإعدادات) + floating voice button + offline sync watcher.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models/transaction.dart';
import '../providers/plan_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/billing_service.dart';
import '../services/sync_service.dart';
import '../utils/constants.dart';
import 'add_transaction/add_transaction_sheet.dart';
import 'budgets/budgets_screen.dart';
import 'chat/chat_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _syncToastShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapAfterHome();
    });
  }

  Future<void> _bootstrapAfterHome() async {
    // 1) Refresh PRO state from the encrypted cache.
    ref.read(isProProvider.notifier).set(BillingService.revalidatePro());
    // 2) Kick a full sync (push pending + pull if empty).
    final bool changed = await ref.read(syncServiceProvider).syncAll(
      onLocalReplaced: (List<Transaction> txs) {
        ref.read(transactionListProvider.notifier).replaceAll(txs);
      },
    );
    if (changed && mounted && !_syncToastShown) {
      _syncToastShown = true;
      Fluttertoast.showToast(msg: 'تمت مزامنة بياناتك ☁️');
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to connectivity changes: sync whenever we come back online.
    ref.listen<AsyncValue<List<ConnectivityResult>>>(
      connectivityProvider,
      (AsyncValue<List<ConnectivityResult>>? prev,
          AsyncValue<List<ConnectivityResult>> next) {
        final List<ConnectivityResult>? results = next.value;
        if (results == null) return;
        final bool online = results.any(
            (ConnectivityResult r) => r != ConnectivityResult.none);
        if (online) {
          ref.read(syncServiceProvider).syncAll(
            onLocalReplaced: (List<Transaction> txs) {
              ref.read(transactionListProvider.notifier).replaceAll(txs);
            },
          );
        }
      },
    );

    final List<Widget> pages = <Widget>[
      const DashboardScreen(),
      const BudgetsScreen(),
      const ChatScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: _HomeFab(
        onPressed: _openAddSheet,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onTap: (int i) => setState(() => _index = i),
      ),
    );
  }

  void _openAddSheet() {
    AddTransactionSheet.maybeShow(context, ref);
  }
}

// ---------------------------------------------------------------------------
// Center FAB — voice-first add: mic by default, opens the add sheet on long
// press. <3 clicks: mic -> speak -> auto-filled sheet -> save.
// ---------------------------------------------------------------------------
class _HomeFab extends StatelessWidget {
  const _HomeFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onPressed,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.green, Color(0xFF00A97F)],
          ),
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.green.withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: AppColors.white, size: 30),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _item(0, Icons.dashboard_rounded, Icons.dashboard_outlined, 'الرئيسية'),
          _item(1, Icons.savings_rounded, Icons.savings_outlined, 'الميزانيات'),
          const SizedBox(width: 56),
          _item(2, Icons.forum_rounded, Icons.forum_outlined, 'المحاسب الآلي'),
          _item(3, Icons.pie_chart_rounded, Icons.pie_chart_outline_rounded,
              'التقارير'),
          _item(4, Icons.settings_rounded, Icons.settings_outlined, 'الإعدادات'),
        ],
      ),
    );
  }

  Widget _item(int index, IconData active, IconData inactive, String label) {
    final bool selected = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(selected ? active : inactive,
                size: 22,
                color: selected ? AppColors.green : AppColors.textHint),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.green : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
