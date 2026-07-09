import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ==========================================
/// TEK KAYNAK MARKA RENGİ — "Sade İndigo"
/// Önceki tema, Apple sistem renklerinin (yeşil/turuncu/kırmızı/teal)
/// hepsini bir arada kullanıyordu; bu da gözde renk kalabalığı ve
/// "birbirine uymayan" bir his yaratıyordu. Yeni palet tek bir sakin
/// vurgu rengine (indigo) ve durum renklerinin çok kısılmış, düşük
/// doygunlukta tonlarına dayanıyor.
/// ==========================================
const Color kBrandAccent = Color(0xFF4C5FD9);
const Color kBrandAccentDeep = Color(0xFF3B4BAE);
const Color kInk = Color(0xFF15161B);

/// Kartlarda / yüzeylerde tutarlı köşe yarıçapı kullanmak için ortak
/// referans değerler. Yeni eklenen ekranlar (ör. ConsentPage) bunu kullanır;
/// mevcut ekranlar kademeli olarak buna taşınabilir.
class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
}

/// Minimal/sade tema için gölgeler kasıtlı olarak çok hafif tutuluyor —
/// derinlik hissi ağırlıklı olarak ince kenarlıklarla (cardBorder) veriliyor,
/// gölge sadece çok az bir "kaldırma" hissi için kullanılıyor.
class AppShadows {
  static List<BoxShadow> card(Color base) => [
    BoxShadow(color: base.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
  ];

  static List<BoxShadow> raised(Color tint) => [
    BoxShadow(color: tint.withOpacity(0.14), blurRadius: 14, offset: const Offset(0, 6)),
  ];
}

/// ==========================================
/// TASARIM YÖNÜ: "iOS Atölye Göstergesi"
/// Apple'ın sistem renk paleti (systemRed/Orange/Green/Teal, label/
/// secondaryLabel, systemBackground/systemGroupedBackground) ile atölye/
/// gösterge panosu kimliğini (gradient hero kart, ibre göstergesi, bilet
/// kenarı) birleştirir. Artık gerçek Cupertino bileşenleri kullanılıyor.
/// ==========================================
/// TASARIM YÖNÜ: "Sade Stüdyo"
/// Önceki tema Apple'ın canlı sistem renklerinin (systemRed/Orange/Green/Teal)
/// hepsini bir arada kullanıyordu — göz için kalabalık ve iddialıydı.
/// Bu palet minimal/sade bir yaklaşım izler: tek bir sakin vurgu rengi
/// (indigo), çok kısılmış/düşük doygunlukta durum renkleri, bol nötr gri
/// ve ince kenarlıklarla oluşan sakin bir yüzey hiyerarşisi.
/// ==========================================
class AppColors {
  final Color navy; // birincil metin
  final Color steel; // ikincil vurgu (nötr mavi-gri, ikonlar için)
  final Color crimson; // tehlike / hasar (kısılmış kırmızı)
  final Color amber; // uyarı (kısılmış amber)
  final Color leaf; // olumlu / temiz durum (kısılmış yeşil)
  final Color slate; // ikincil metin
  final Color scaffoldBg; // sayfa arka planı
  final Color cardBg; // kart yüzeyi
  final Color cardBorder; // ince ayraç çizgisi
  final Color heroGradientStart;
  final Color heroGradientEnd;
  final Color accent; // imza rengi: sakin indigo

  const AppColors({
    required this.navy,
    required this.steel,
    required this.crimson,
    required this.amber,
    required this.leaf,
    required this.slate,
    required this.scaffoldBg,
    required this.cardBg,
    required this.cardBorder,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.accent,
  });

  static const light = AppColors(
    navy: Color(0xFF16171C),
    steel: Color(0xFF5B6478),
    crimson: Color(0xFFC2483F),
    amber: Color(0xFFB8842E),
    leaf: Color(0xFF3F8C52),
    slate: Color(0xFF767B87),
    scaffoldBg: Color(0xFFFAFAFB),
    cardBg: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE7E8EC),
    heroGradientStart: Color(0xFF15161B),
    heroGradientEnd: Color(0xFF15161B),
    accent: Color(0xFF4C5FD9),
  );

  static const dark = AppColors(
    navy: Color(0xFFF2F3F5),
    steel: Color(0xFF9AA1B4),
    crimson: Color(0xFFDD776F),
    amber: Color(0xFFD1A25E),
    leaf: Color(0xFF6EBA7F),
    slate: Color(0xFF979CA8),
    scaffoldBg: Color(0xFF0E0F12),
    cardBg: Color(0xFF191A1F),
    cardBorder: Color(0xFF2A2B32),
    heroGradientStart: Color(0xFF191A1F),
    heroGradientEnd: Color(0xFF191A1F),
    accent: Color(0xFF8891E8),
  );
}

/// `context.colors.navy` ile kısa erişim. Etkin parlaklığı CupertinoTheme'den
/// okur (AppTheme.resolve, ThemeController'a bağlı olarak brightness set eder).
extension AppColorsX on BuildContext {
  AppColors get colors =>
      CupertinoTheme.brightnessOf(this) == Brightness.dark ? AppColors.dark : AppColors.light;
}

/// Tipografi: Cupertino ortamında varsayılan yazı tipi iOS'ta San Francisco'dur,
/// bu yüzden `display` metinleri özel bir font ailesi ZORLAMAZ — platformun
/// native fontunu kullanır. Sayısal/plaka gibi hizalı veriler için iOS'un
/// yerleşik monospace fontu "Menlo" kullanılır.
class AppFonts {
  static TextStyle display({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = 0,
    double? height,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
}

/// Material'daki ThemeMode'un yerini alan, tamamen Cupertino/native akışa
/// uygun basit bir enum.
enum AppThemeMode { system, light, dark }

class AppTheme {
  static Brightness _brightnessFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return PlatformDispatcher.instance.platformBrightness;
    }
  }

  static CupertinoThemeData resolve(AppThemeMode mode) {
    final brightness = _brightnessFor(mode);
    final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: c.accent,
      scaffoldBackgroundColor: c.scaffoldBg,
      barBackgroundColor: c.cardBg.withOpacity(0.94),
      textTheme: CupertinoTextThemeData(
        primaryColor: c.accent,
        textStyle: TextStyle(fontSize: 16, color: c.navy),
        navTitleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.navy),
        navLargeTitleTextStyle: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: c.navy),
        actionTextStyle: TextStyle(fontSize: 16, color: c.accent),
      ),
    );
  }
}

/// Uygulama genelinde tema modunu (light/dark/system) tutan controller.
/// Seçim SharedPreferences ile kalıcı olarak saklanır. Sistem parlaklığı
/// değiştiğinde (mode == system iken) arayüzün tepki vermesi main.dart'taki
/// WidgetsBindingObserver ile sağlanır.
class ThemeController {
  ThemeController._();
  static const _key = 'theme_mode_v1';
  static final ValueNotifier<AppThemeMode> mode = ValueNotifier(AppThemeMode.system);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    switch (saved) {
      case 'light':
        mode.value = AppThemeMode.light;
        break;
      case 'dark':
        mode.value = AppThemeMode.dark;
        break;
      default:
        mode.value = AppThemeMode.system;
    }
  }

  static Future<void> setMode(AppThemeMode newMode) async {
    mode.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, newMode.name);
  }
}