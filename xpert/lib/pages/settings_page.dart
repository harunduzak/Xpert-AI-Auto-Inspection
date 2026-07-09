import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../core/history_store.dart';
import '../core/reports_store.dart';
import '../theme/app_theme.dart';
import '../core/language_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _confirmClearHistory(BuildContext context, bool isTr) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(isTr ? 'Geçmişi Temizle' : 'Clear History'),
        content: Text(isTr
            ? 'Tüm analiz geçmişi ve oluşturulan PDF raporları kalıcı olarak silinecek. Emin misiniz?'
            : 'All analysis history and generated PDF reports will be permanently deleted. Are you sure?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(isTr ? 'Vazgeç' : 'Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(isTr ? 'Sil' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final reports = ReportsStore.getAll();
      for (final r in reports) {
        try {
          final file = File(r.pdfPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      await ReportsStore.clear();
      await HistoryStore.clear();
      if (context.mounted) {
        _showToast(context, isTr ? 'Geçmiş ve raporlar temizlendi' : 'History and reports cleared');
      }
    }
  }

  void _showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final c = context.colors;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 50, left: 40, right: 40,
        child: _ToastBubble(message: message, color: c),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1800), () => entry.remove());
  }

  void _openGuide(BuildContext context, {required String title, required Widget content}) {
    final c = context.colors;
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (routeContext) => CupertinoPageScaffold(
          backgroundColor: c.scaffoldBg,
          navigationBar: CupertinoNavigationBar(
            middle: Text(title),
            backgroundColor: c.cardBg.withOpacity(0.94),
            border: Border(bottom: BorderSide(color: c.cardBorder, width: 0.5)),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () => Navigator.of(routeContext).pop(),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: c.navy, size: 22),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  // İpucu Maddeleri için sabit şablon (Fotoğraf çekme tüyoları için)
  Widget _buildTipItem(BuildContext context, String number, String text) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.steel.withOpacity(0.15), shape: BoxShape.circle),
            child: Text(number, style: TextStyle(color: c.navy, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: TextStyle(color: c.navy, fontSize: 14.5, height: 1.5)),
            ),
          ),
        ],
      ),
    );
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
              child: CustomScrollView(
                slivers: [
                  CupertinoSliverNavigationBar(
                    largeTitle: Text(isTr ? 'Ayarlar' : 'Settings'),
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 8),

                      // --- GÖRÜNÜM ---
                      CupertinoListSection.insetGrouped(
                        header: Text(isTr ? 'GÖRÜNÜM' : 'APPEARANCE'),
                        backgroundColor: c.scaffoldBg,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: ValueListenableBuilder<AppThemeMode>(
                              valueListenable: ThemeController.mode,
                              builder: (context, mode, _) {
                                return CupertinoSlidingSegmentedControl<AppThemeMode>(
                                  groupValue: mode,
                                  children: {
                                    AppThemeMode.system: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                        child: Text(isTr ? 'Sistem' : 'System')),
                                    AppThemeMode.light: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                        child: Text(isTr ? 'Aydınlık' : 'Light')),
                                    AppThemeMode.dark: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                        child: Text(isTr ? 'Karanlık' : 'Dark')),
                                  },
                                  onValueChanged: (v) {
                                    if (v != null) ThemeController.setMode(v);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // --- DİL ---
                      CupertinoListSection.insetGrouped(
                        header: Text(isTr ? 'DİL' : 'LANGUAGE'),
                        backgroundColor: c.scaffoldBg,
                        children: [
                          CupertinoListTile(
                            leading: const Text('🇹🇷', style: TextStyle(fontSize: 20)),
                            title: Text('Türkçe', style: TextStyle(color: c.navy, fontWeight: FontWeight.w600)),
                            trailing: isTr ? Icon(Icons.check_circle_rounded, color: c.leaf) : null,
                            onTap: () => LanguageController.setLang('tr'),
                          ),
                          CupertinoListTile(
                            leading: const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                            title: Text('English', style: TextStyle(color: c.navy, fontWeight: FontWeight.w600)),
                            trailing: !isTr ? Icon(Icons.check_circle_rounded, color: c.leaf) : null,
                            onTap: () => LanguageController.setLang('en'),
                          ),
                        ],
                      ),

                      // --- KULLANICI KILAVUZU VE DESTEK ---
                      CupertinoListSection.insetGrouped(
                        header: Text(isTr ? 'KULLANICI KILAVUZU VE DESTEK' : 'USER GUIDE & SUPPORT'),
                        backgroundColor: c.scaffoldBg,
                        children: [
                          CupertinoListTile(
                            leading: Icon(Icons.help_outline_rounded, color: c.steel),
                            title: Text(isTr ? 'Sıkça Sorulan Sorular' : 'FAQ',
                                style: TextStyle(color: c.navy, fontWeight: FontWeight.w600)),
                            trailing: Icon(Icons.chevron_right_rounded, color: c.slate, size: 20),
                            onTap: () => _openGuide(
                              context,
                              title: isTr ? 'Sıkça Sorulan Sorular' : 'FAQ',
                              content: Column(
                                children: isTr
                                    ? [
                                  _FaqAccordionItem(question: 'Sonuçlar ne kadar güvenilir?', answer: 'Yapay zeka modelleri yüksek doğrulukla çalışır ancak %100 kesinlik garanti edilmez. Düşük güven skorlu sonuçları ekspertiz uzmanına doğrulatmanızı öneririz.', colors: c),
                                  _FaqAccordionItem(question: 'Verilerim nerede saklanıyor?', answer: 'Fotoğraflar ve analiz geçmişi yalnızca cihazınızda saklanır, kesinlikle uzak bir sunucuya gönderilmez.', colors: c),
                                  _FaqAccordionItem(question: 'Bir analizi nasıl silerim?', answer: 'Geçmiş sekmesinde bir kaydı sola kaydırabilir veya "Seç" butonu ile birden fazla kaydı işaretleyip toplu silebilirsiniz.', colors: c),
                                  _FaqAccordionItem(question: 'PDF raporunu nasıl paylaşırım?', answer: 'Analiz raporu ekranında sağ üstteki veya butonlar alanındaki "Paylaş" ikonuna basarak WhatsApp, e-posta veya diğer kanallarla raporu gönderebilirsiniz.', colors: c),
                                  _FaqAccordionItem(question: 'Uygulama internetsiz çalışır mı?', answer: 'Hayır. Yapay zeka tarama ve plaka okuma modellerinin kararlı çalışması ve güncel veri tabanı kontrolü için aktif bir internet bağlantısı gerekir.', colors: c),
                                  _FaqAccordionItem(question: 'Hangi araç türlerini destekliyor?', answer: 'Binek otomobiller, SUV ve hafif ticari araçların büyük çoğunluğunu destekler; marka, model grubu ve kasa tipini otomatik olarak eşleştirir.', colors: c),
                                ]
                                    : [
                                  _FaqAccordionItem(question: 'How reliable are the results?', answer: 'Our AI models are highly accurate but not 100% guaranteed. We recommend having low-confidence results verified by a licensed appraiser.', colors: c),
                                  _FaqAccordionItem(question: 'Where is my data stored?', answer: 'Photos and analysis history are stored only on your device and are never sent to an external server.', colors: c),
                                  _FaqAccordionItem(question: 'How do I delete an analysis?', answer: 'Swipe a record left in the History tab, or tap "Select" to check multiple records and delete them in bulk.', colors: c),
                                  _FaqAccordionItem(question: 'How do I share the PDF report?', answer: 'You can share reports via WhatsApp, email, or other communication apps by tapping the "Share" icon on the report screen.', colors: c),
                                  _FaqAccordionItem(question: 'Does the app work offline?', answer: 'No. An active internet connection is required for the accurate operation of our AI scanning and plate reading models.', colors: c),
                                  _FaqAccordionItem(question: 'Which vehicle types are supported?', answer: 'It supports the vast majority of passenger cars, SUVs, and light commercial vehicles, automatically matching the brand and body type.', colors: c),
                                ],
                              ),
                            ),
                          ),
                          CupertinoListTile(
                            leading: Icon(Icons.camera_alt_outlined, color: c.steel),
                            title: Text(isTr ? 'En İyi Fotoğrafı Nasıl Çekerim' : 'How to Take the Best Photo',
                                style: TextStyle(color: c.navy, fontWeight: FontWeight.w600)),
                            trailing: Icon(Icons.chevron_right_rounded, color: c.slate, size: 20),
                            onTap: () => _openGuide(
                              context,
                              title: isTr ? 'En İyi Fotoğraf İçin İpuçları' : 'Best Photo Tips',
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: isTr
                                    ? [
                                  _buildTipItem(context, '1', 'İyi ışıklandırılmış, gündüz ortamını tercih edin.'),
                                  _buildTipItem(context, '2', 'Aracın tamamı kadraja girecek şekilde 2-3 metre mesafeden çekin.'),
                                  _buildTipItem(context, '3', 'Plaka ve hasarlı bölgeyi net görebileceğiniz açılardan ayrı fotoğraflar ekleyin.'),
                                  _buildTipItem(context, '4', 'Yansıma, gölge ve bulanıklıktan kaçının.'),
                                  _buildTipItem(context, '5', 'Islak veya çamurlu yüzeylerde hasar tespiti zorlaşabilir; mümkünse temiz bir yüzeyde çekim yapın.'),
                                ]
                                    : [
                                  _buildTipItem(context, '1', 'Prefer well-lit, daytime conditions.'),
                                  _buildTipItem(context, '2', 'Shoot from about 2-3 meters so the whole vehicle fits in frame.'),
                                  _buildTipItem(context, '3', 'Add separate close-up shots of the plate and any damaged areas.'),
                                  _buildTipItem(context, '4', 'Avoid glare, harsh shadows, and blur.'),
                                  _buildTipItem(context, '5', 'Damage detection is harder on wet or muddy surfaces — a clean surface works best.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // --- VERİ ---
                      CupertinoListSection.insetGrouped(
                        header: Text(isTr ? 'VERİ' : 'DATA'),
                        backgroundColor: c.scaffoldBg,
                        children: [
                          CupertinoListTile(
                            leading: Icon(Icons.delete_outline_rounded, color: c.crimson, size: 22),
                            title: Text(isTr ? 'Geçmişi Temizle' : 'Clear History',
                                style: TextStyle(color: c.navy, fontWeight: FontWeight.w600)),
                            subtitle: Text(isTr
                                ? 'Kayıtlı tüm analizleri kalıcı olarak siler'
                                : 'Permanently deletes all saved analyses',
                                style: TextStyle(color: c.slate, fontSize: 12)),
                            trailing: Icon(Icons.chevron_right_rounded, color: c.slate, size: 20),
                            onTap: () => _confirmClearHistory(context, isTr),
                          ),
                        ],
                      ),

                      // --- HAKKINDA ---
                      CupertinoListSection.insetGrouped(
                        header: Text(isTr ? 'HAKKINDA' : 'ABOUT'),
                        backgroundColor: c.scaffoldBg,
                        footer: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            isTr
                                ? 'Bu uygulama yapay zeka destekli araç, hasar ve plaka tespiti yapar. '
                                'Sonuçlar sadece bilgilendirme amaçlıdır; kesin ekspertiz raporu yerine geçmez.'
                                : 'This app performs AI-supported vehicle, damage, and license plate detection. '
                                'Results are for informational purposes only and do not replace an official appraisal report.',
                            style: TextStyle(color: c.slate, fontSize: 12.5, height: 1.4),
                          ),
                        ),
                        children: [
                          CupertinoListTile(
                            leading: Icon(Icons.info_outline_rounded, color: c.steel),
                            title: Text('Xpert',
                                style: TextStyle(color: c.navy, fontSize: 15.5, fontWeight: FontWeight.w600)),
                            subtitle: Text(isTr ? 'Sürüm 1.1' : 'Version 1.1',
                                style: TextStyle(color: c.slate, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ],
              ),
            ),
          );
        });
  }
}

// Yeni Eklenen Açılır-Kapanır (Accordion) SSS Widget'ı
class _FaqAccordionItem extends StatefulWidget {
  final String question;
  final String answer;
  final AppColors colors;

  const _FaqAccordionItem({
    required this.question,
    required this.answer,
    required this.colors,
  });

  @override
  State<_FaqAccordionItem> createState() => _FaqAccordionItemState();
}

class _FaqAccordionItemState extends State<_FaqAccordionItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: TextStyle(color: c.navy, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: c.slate,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.answer,
                style: TextStyle(color: c.slate, fontSize: 14, height: 1.5),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _ToastBubble extends StatefulWidget {
  final String message;
  final AppColors color;
  const _ToastBubble({required this.message, required this.color});

  @override
  State<_ToastBubble> createState() => _ToastBubbleState();
}

class _ToastBubbleState extends State<_ToastBubble> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 20), () {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.black.withOpacity(0.82),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          widget.message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CupertinoColors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}