// ==========================================
// onboarding_page.dart
// Uygulamaya girişte gösterilen, sağa/sola kaydırmalı 3 sayfalık akış:
//   1) Uygulamanın neler sunduğu (özellik listesi - GENİŞLETİLDİ)
//   2) Yapay zeka destekli olduğu tanıtımı
//   3) Bilgilendirme + onay (checkbox işaretlenmeden ilerlenemez)
// Onay son sayfada verilir ve tek seferliktir (bir daha gösterilmez).
// ==========================================
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../core/language_controller.dart';
import 'home_shell.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageCtrl = PageController();
  int _currentIndex = 0;
  bool _consentChecked = false;

  static const int _pageCount = 3;
  bool get _isLastPage => _currentIndex == _pageCount - 1;
  bool get _canProceed => !_isLastPage || _consentChecked;

  Future<void> _finish() async {
    if (!_consentChecked) return;
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_onboarding', false);
    await prefs.setBool('ai_consent_accepted', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }

  void _next() {
    if (_isLastPage) {
      _finish();
    } else {
      HapticFeedback.selectionClick();
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ValueListenableBuilder<String>(
      valueListenable: LanguageController.lang,
      builder: (context, lang, _) {
        final isTr = LanguageController.isTr;

        return CupertinoPageScaffold(
          backgroundColor: c.scaffoldBg,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 12, 0),
                  child: Row(
                    children: [
                      Text(
                        isTr ? 'ADIM ${_currentIndex + 1}/$_pageCount' : 'STEP ${_currentIndex + 1}/$_pageCount',
                        style: AppFonts.mono(
                            fontSize: 11, color: c.slate, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(isTr ? 'EN' : 'TR',
                            style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
                        onPressed: () => LanguageController.setLang(isTr ? 'en' : 'tr'),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    children: [
                      // SIRA DEĞİŞTİ: Artık 1. Sayfa "Özellikler", 2. Sayfa "Yapay Zeka Tanıtımı"
                      _FeaturesPage(color: c, isTr: isTr),
                      _IntroPage(color: c, isTr: isTr),
                      _ConsentPageView(
                        color: c,
                        isTr: isTr,
                        checked: _consentChecked,
                        onChanged: (v) => setState(() => _consentChecked = v),
                      ),
                    ],
                  ),
                ),

                // --- Alt Kontroller (Noktalar ve Buton) ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: List.generate(
                              _pageCount,
                                  (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 8),
                                height: 8,
                                width: _currentIndex == i ? 24 : 8,
                                decoration: BoxDecoration(
                                  color: _currentIndex == i ? c.accent : c.slate.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                            child: CupertinoButton(
                              key: ValueKey('$_isLastPage-$_canProceed'),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              color: _canProceed ? kInk : c.cardBorder,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              onPressed: _canProceed ? _next : null,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isLastPage) ...[
                                    Icon(Icons.check_circle_rounded,
                                        size: 16, color: _canProceed ? kBrandAccent : c.slate),
                                    const SizedBox(width: 7),
                                  ],
                                  Text(
                                    _isLastPage
                                        ? (isTr ? 'Kabul Ediyorum ve Başla' : 'I Accept and Start')
                                        : (isTr ? 'İleri' : 'Next'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _canProceed ? CupertinoColors.white : c.slate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_isLastPage && !_consentChecked)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            isTr ? 'Devam etmek için kutuyu işaretleyin' : 'Check the box to continue',
                            style: TextStyle(fontSize: 11.5, color: c.slate, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// --- Sayfa 1: Uygulamanın neler sunduğu (GENİŞLETİLDİ VE DÜZENLENDİ) ---
class _FeaturesPage extends StatelessWidget {
  final AppColors color;
  final bool isTr;
  const _FeaturesPage({required this.color, required this.isTr});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
      Icons.directions_car_filled_rounded,
      isTr ? 'Araç & Plaka Tespiti' : 'Vehicle & Plate Detection',
      isTr ? 'Araç tipini ve plakayı otomatik olarak tanır.' : 'Automatically recognizes vehicle type and plate.',
      ),
      (
      Icons.warning_amber_rounded,
      isTr ? 'Parça Bazlı Hasar Analizi' : 'Part-Based Damage Analysis',
      isTr ? 'Hasarları ilgili araç parçasıyla eşleştirerek listeler.' : 'Matches damages to the related vehicle part.',
      ),
      (
      Icons.bolt_rounded,
      isTr ? 'Saniyeler İçinde Sonuç' : 'Results in Seconds',
      isTr ? 'Birden fazla fotoğrafı art arda analiz edebilirsiniz.' : 'Analyze multiple photos back to back.',
      ),
      (
      Icons.picture_as_pdf_rounded,
      isTr ? 'PDF Rapor ve Paylaşım' : 'PDF Report & Sharing',
      isTr ? 'Sonuçları anında PDF rapora dönüştürüp paylaşın.' : 'Turn results into a PDF report and share instantly.',
      ),
      (
      Icons.lock_outline_rounded,
      isTr ? 'Geçmiş Cihazda Saklanır' : 'History Stays On-Device',
      isTr ? 'Analiz geçmişiniz yalnızca kendi cihazınızda tutulur.' : 'Your analysis history is kept only on your device.',
      ),
    ];

    // Padding daraltıldı (geniş görünüm için 28 -> 20 yapıldı)
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'Neler Sunuyoruz' : 'What We Offer',
            style: AppFonts.display(fontSize: 24, fontWeight: FontWeight.bold, color: color.navy), // Başlık büyütüldü
          ),
          const SizedBox(height: 6),
          Text(
            isTr ? 'Tek bir uygulamada araç ön değerlendirmesi.' : 'Preliminary vehicle assessment, all in one app.',
            style: TextStyle(fontSize: 14.5, color: color.slate), // Alt başlık büyütüldü
          ),
          const SizedBox(height: 24), // Boşluk artırıldı
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(), // Küçük ekranlarda rahat scroll için eklendi
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final (icon, title, desc) = items[i];
                return Container(
                  // Kart içi boşluklar (padding) daha rahat bir görünüm için artırıldı
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: color.cardBg,
                    borderRadius: BorderRadius.circular(16), // Kenarlar yumuşatıldı
                    border: Border.all(color: color.cardBorder),
                    boxShadow: AppShadows.card(CupertinoColors.black),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color.accent, size: 20), // İkonlar büyütüldü
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: AppFonts.display(
                                    fontSize: 14.5, fontWeight: FontWeight.w700, color: color.navy)), // Başlık fontu büyütüldü
                            const SizedBox(height: 3),
                            Text(desc, style: TextStyle(fontSize: 12.5, color: color.slate, height: 1.35)), // Açıklama fontu büyütüldü
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// --- Sayfa 2: Yapay zeka destekli olduğu tanıtımı ---
class _IntroPage extends StatelessWidget {
  final AppColors color;
  final bool isTr;
  const _IntroPage({required this.color, required this.isTr});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: kInk, shape: BoxShape.circle, boxShadow: AppShadows.raised(kInk)),
            child: const Icon(Icons.smart_toy_rounded, size: 76, color: kBrandAccent),
          ),
          const SizedBox(height: 40),
          Text(
            isTr ? 'Yapay Zeka Desteği' : 'AI Powered',
            textAlign: TextAlign.center,
            style: AppFonts.display(fontSize: 24, fontWeight: FontWeight.bold, color: color.navy),
          ),
          const SizedBox(height: 16),
          Text(
            isTr
                ? 'Bu uygulama, araç fotoğraflarınızı tamamen cihazınızda çalışan yapay zeka modelleriyle analiz eder. Araç, plaka ve hasar tespitleri otomatik olarak, saniyeler içinde üretilir.'
                : 'This app analyzes your vehicle photos using AI models that run entirely on your device. Vehicle, plate, and damage detections are generated automatically, in seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: color.slate, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// --- Sayfa 3: Bilgilendirme + Onay ---
class _ConsentPageView extends StatelessWidget {
  final AppColors color;
  final bool isTr;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _ConsentPageView({
    required this.color,
    required this.isTr,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'Bilgilendirme ve Onay' : 'Disclosure & Consent',
            style: AppFonts.display(fontSize: 22, fontWeight: FontWeight.bold, color: color.navy),
          ),
          const SizedBox(height: 4),
          Text(
            isTr ? 'Devam etmeden önce lütfen okuyun.' : 'Please read before continuing.',
            style: TextStyle(fontSize: 13.5, color: color.slate),
          ),
          const SizedBox(height: 18),

          _DisclosureRow(
            color: color,
            icon: Icons.error_outline_rounded,
            text: isTr
                ? 'Yapay zeka bazı hasarları veya bilgileri gözden kaçırabilir ya da yanlış tespit edebilir.'
                : 'The AI can miss or misidentify some damages or information.',
          ),
          _DisclosureRow(
            color: color,
            icon: Icons.gavel_rounded,
            text: isTr
                ? 'Sonuçlar yalnızca bilgilendirme amaçlıdır; resmi ekspertiz raporu yerine geçmez.'
                : 'Results are for information only and do not replace an official appraisal report.',
          ),
          _DisclosureRow(
            color: color,
            icon: Icons.lock_outline_rounded,
            text: isTr
                ? 'Fotoğraflarınız ve analiz geçmişiniz yalnızca cihazınızda saklanır, sunucuya gönderilmez.'
                : 'Your photos and analysis history are stored only on your device, never sent to a server.',
          ),

          const SizedBox(height: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(!checked);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: checked ? kBrandAccent.withOpacity(0.08) : color.cardBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: checked ? kBrandAccent.withOpacity(0.55) : color.cardBorder,
                  width: 1.2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: checked ? kBrandAccent : CupertinoColors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: checked ? kBrandAccent : color.slate, width: 1.6),
                    ),
                    child: checked
                        ? const Icon(Icons.check_rounded, size: 16, color: CupertinoColors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isTr
                          ? 'Yukarıdaki bilgilendirmeyi okudum, anladım ve kabul ediyorum.'
                          : 'I have read, understood, and accept the notice above.',
                      style: TextStyle(
                          fontSize: 13, color: color.navy, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  final AppColors color;
  final IconData icon;
  final String text;
  const _DisclosureRow({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.cardBorder),
          boxShadow: AppShadows.card(CupertinoColors.black),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.steel.withOpacity(0.10), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color.steel, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 12.5, color: color.slate, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}