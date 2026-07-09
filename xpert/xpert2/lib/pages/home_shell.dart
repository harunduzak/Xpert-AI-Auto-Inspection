import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons, BottomNavigationBarItem;

import '../theme/app_theme.dart';
import '../core/language_controller.dart'; // EKLENDİ
import 'dashboard_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Key _historyKey = UniqueKey();
  Key _dashboardKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Dil değiştiğinde alt menünün de anında güncellenmesi için ValueListenableBuilder ile sarmaladık
    return ValueListenableBuilder<String>(
        valueListenable: LanguageController.lang,
        builder: (context, lang, _) {
          final isTr = LanguageController.isTr;

          return CupertinoTabScaffold(
            tabBar: CupertinoTabBar(
              backgroundColor: c.cardBg,
              activeColor: c.accent,
              inactiveColor: c.slate,
              border: Border(top: BorderSide(color: c.cardBorder, width: 0.5)),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  label: isTr ? 'Ana Sayfa' : 'Home',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.history),
                  activeIcon: const Icon(Icons.history),
                  label: isTr ? 'Geçmiş' : 'History',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings_outlined),
                  activeIcon: const Icon(Icons.settings),
                  label: isTr ? 'Ayarlar' : 'Settings',
                ),
              ],
              onTap: (i) {
                if (i == 0) setState(() => _dashboardKey = UniqueKey());
                if (i == 1) setState(() => _historyKey = UniqueKey());
              },
            ),
            tabBuilder: (context, index) {
              switch (index) {
                case 0:
                  return CupertinoTabView(builder: (_) => DashboardPage(key: _dashboardKey));
                case 1:
                  return CupertinoTabView(builder: (_) => HistoryPage(key: _historyKey));
                default:
                  return const CupertinoTabView(builder: _buildSettings);
              }
            },
          );
        }
    );
  }

  static Widget _buildSettings(BuildContext context) => const SettingsPage();
}