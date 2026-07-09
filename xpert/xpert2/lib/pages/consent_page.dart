// ==========================================
// consent_page.dart
// İlk açılışta gösterilen "Yapay Zeka Bilgilendirme ve Onay" ekranı.
// Kullanıcı onay kutusunu işaretleyip "Kabul Ediyorum" demeden
// uygulamanın geri kalanına geçemez.
// ==========================================
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../core/language_controller.dart';
import 'onboarding_page.dart';

class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key});

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _accepted = false;

  Future<void> _continue() async {
    if (!_accepted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_consent_accepted', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const OnboardingPage()),
      );
    }
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
                Align(
                  alignment: Alignment.topRight,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Text(isTr ? 'EN' : 'TR',
                        style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
                    onPressed: () => LanguageController.setLang(isTr ? 'en' : 'tr'),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [kInk, c.heroGradientEnd],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: AppShadows.raised(kInk),
                            ),
                            child: const Icon(Icons.smart_toy_rounded, color: kBrandAccent, size: 36),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isTr ? 'Yapay Zeka Bilgilendirmesi' : 'AI Disclosure',
                          textAlign: TextAlign.center,
                          style: AppFonts.display(fontSize: 22, fontWeight: FontWeight.w800, color: c.navy),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isTr
                              ? 'Devam etmeden önce lütfen aşağıdakileri okuyun.'
                              : 'Please read the following before continuing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.slate, fontSize: 13.5),
                        ),
                        const SizedBox(height: 24),

                        _InfoRow(
                          color: c,
                          icon: Icons.psychology_alt_rounded,
                          title: isTr ? 'Sonuçlar yapay zeka ile üretilir' : 'Results are AI-generated',
                          desc: isTr
                              ? 'Araç, hasar ve plaka tespitleri cihazınızda çalışan yapay zeka modelleri tarafından otomatik olarak üretilir. Bu bir insan uzman değerlendirmesi değildir.'
                              : 'Vehicle, damage, and plate detections are produced automatically by AI models running on your device. This is not a human expert assessment.',
                        ),
                        _InfoRow(
                          color: c,
                          icon: Icons.error_outline_rounded,
                          title: isTr ? 'Hatalı veya eksik sonuçlar olabilir' : 'Results may be wrong or incomplete',
                          desc: isTr
                              ? 'Yapay zeka modelleri bazı hasarları veya bilgileri gözden kaçırabilir ya da yanlış tespit edebilir. Sonuçlar sadece bilgilendirme ve ön izlenim amaçlıdır.'
                              : 'AI models can miss or misidentify damages and information. Results are for information and a preliminary impression only.',
                        ),
                        _InfoRow(
                          color: c,
                          icon: Icons.gavel_rounded,
                          title: isTr ? 'Resmi ekspertiz raporu yerine geçmez' : 'Does not replace an official appraisal',
                          desc: isTr
                              ? 'Alım-satım, sigorta veya hukuki işlemler için mutlaka yetkili bir ekspertiz kurumuna başvurun. Bu uygulama karar verme aracı değil, ön bilgi aracıdır.'
                              : 'For purchase, insurance, or legal matters, always consult a licensed appraisal service. This app is an informational aid, not a decision-making tool.',
                        ),
                        _InfoRow(
                          color: c,
                          icon: Icons.lock_outline_rounded,
                          title: isTr ? 'Verileriniz cihazınızda saklanır' : 'Your data stays on your device',
                          desc: isTr
                              ? 'Yüklediğiniz fotoğraflar ve analiz geçmişi yalnızca kendi cihazınızda tutulur; bir sunucuya gönderilmez.'
                              : 'Photos you upload and your analysis history are kept only on your own device; they are not sent to a server.',
                        ),

                        const SizedBox(height: 22),
                        _ConsentCheckbox(
                          color: c,
                          value: _accepted,
                          onChanged: (v) => setState(() => _accepted = v),
                          label: isTr
                              ? 'Yukarıdaki bilgilendirmeyi okudum, anladım ve kabul ediyorum.'
                              : 'I have read, understood, and accept the notice above.',
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    color: _accepted ? kInk : c.cardBorder,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onPressed: _accepted ? _continue : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 18, color: _accepted ? kBrandAccent : c.slate),
                        const SizedBox(width: 8),
                        Text(
                          isTr ? 'Kabul Ediyorum ve Devam Et' : 'I Accept and Continue',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _accepted ? CupertinoColors.white : c.slate,
                          ),
                        ),
                      ],
                    ),
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

class _InfoRow extends StatelessWidget {
  final AppColors color;
  final IconData icon;
  final String title;
  final String desc;
  const _InfoRow({required this.color, required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
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
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.steel.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color.steel, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppFonts.display(fontSize: 14.5, fontWeight: FontWeight.w700, color: color.navy)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(fontSize: 12.5, color: color.slate, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cupertino'da hazır bir "form onay kutusu" bileşeni olmadığı için
/// dokunulabilir alanı geniş, native hissettiren basit bir checkbox.
class _ConsentCheckbox extends StatelessWidget {
  final AppColors color;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  const _ConsentCheckbox({
    required this.color,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value ? kBrandAccent.withOpacity(0.08) : color.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: value ? kBrandAccent.withOpacity(0.55) : color.cardBorder, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? kBrandAccent : CupertinoColors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: value ? kBrandAccent : color.slate, width: 1.6),
              ),
              child: value
                  ? const Icon(Icons.check_rounded, size: 16, color: CupertinoColors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: color.navy, fontWeight: FontWeight.w600, height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }
}