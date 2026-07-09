// ==========================================
// main.dart
// ==========================================
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/history_store.dart';
import 'core/reports_store.dart';
import 'theme/app_theme.dart';
import 'pages/home_shell.dart';
import 'pages/onboarding_page.dart';

void main() async {
  // Flutter motorunun widget ağacıyla iletişime geçmesini sağlar
  WidgetsFlutterBinding.ensureInitialized();

  // GEÇMİŞ VERİTABANINI BAŞLATIYORUZ
  await HistoryStore.init();
  // OLUŞTURULAN PDF RAPORLARININ LİSTESİNİ BAŞLATIYORUZ
  await ReportsStore.init();

  // Telefonun üst çubuğunu şeffaf yapıp tasarımla bütünleştirir
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Color(0x00000000)),
  );

  // Uygulamanın sadece dikey modda kullanılmasını zorlar
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = prefs.getBool('show_onboarding') ?? true;

  final Widget startPage = showOnboarding ? const OnboardingPage() : const HomeShell();

  runApp(MyApp(startPage: startPage));
}

class MyApp extends StatelessWidget {
  final Widget startPage;

  const MyApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    // Ayarlar sayfasından değiştirilebilen temayı canlı dinler
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {

        // Sistem modundaysa cihazın kendi parlaklık ayarını okur
        final brightness = mode == AppThemeMode.system
            ? MediaQuery.platformBrightnessOf(context)
            : (mode == AppThemeMode.dark ? Brightness.dark : Brightness.light);

        return CupertinoApp(
          title: 'Oto Ekspertiz Pro',
          debugShowCheckedModeBanner: false,
          theme: CupertinoThemeData(
            brightness: brightness,
            primaryColor: kBrandAccent,
            scaffoldBackgroundColor:
            brightness == Brightness.dark ? AppColors.dark.scaffoldBg : AppColors.light.scaffoldBg,
          ),

          // EKLENEN KISIM: Material tasarımların (Dialog vb.) çökmesini engelleyen dosyalar
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('tr', 'TR'), // Türkçe desteği
            Locale('en', 'US'), // İngilizce desteği
          ],

          home: startPage,
        );
      },
    );
  }
}