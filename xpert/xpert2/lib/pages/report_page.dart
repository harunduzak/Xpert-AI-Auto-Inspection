// ==========================================
// report_page.dart
// Güncellemeler:
//  - Fotoğrafın üzerinde duran ve görüntüyü kapatan yarım-daire hasar
//    göstergesi (VerdictGauge) kaldırıldı; artık yalnızca "Hasar Durumu"
//    sekmesinde, fotoğrafın altında kendi kartında gösteriliyor.
//  - "Araç Bilgileri" / "Hasar Durumu" sekmeleri arasındaki görsel ayrım güçlendirildi.
//  - Güven skoru rozetleri (%83.0, %33.8 vb.) için renk eşiği netleştirildi.
//  - Üst gezinme çubuğundaki geri oku elle/garanti bir widget ile veriliyor.
//  - Plaka uyuşmazlığı Dialog'u Material (Android) tasarıma geçirildi.
//  - Analiz döngüsüne (try-catch) koruması eklendi.
// ==========================================
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
// Material kütüphanesini Material Dialog ve Butonları kullanabilmek için genişlettik
import 'package:flutter/material.dart' show Icons, showDialog, AlertDialog, TextButton, Colors, BoxShape;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/language_controller.dart';
import '../core/analyzer.dart';
import '../core/analysis_record.dart';
import '../core/detection.dart';
import '../core/history_store.dart';
import '../core/reports_store.dart';
import '../core/plate_reader.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/verdict_gauge.dart';
import '../widgets/detection_overlay.dart';

class _ImageAnalysis {
  final File image;
  final Map<String, Map<String, dynamic>> results = {};
  List<Detection> parts = [];
  List<Detection> damages = [];
  List<String> damageReport = [];
  bool loading = true;

  _ImageAnalysis(this.image);

  factory _ImageAnalysis.fromRecord(AnalysisRecord r) {
    final a = _ImageAnalysis(File(r.imagePath));
    a.results.addAll(r.idResults);
    a.parts = r.parts;
    a.damages = r.damages;
    a.damageReport = r.damageReport;
    a.loading = false;
    return a;
  }
}

class ReportPage extends StatefulWidget {
  final List<File>? images;
  final File? image;
  final AnalysisRecord? record;

  const ReportPage({super.key, this.images, this.image, this.record})
      : assert(images != null || (image != null && record != null) || image != null,
  'images veya image/record sağlanmalı');

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with SingleTickerProviderStateMixin {
  final List<String> _idPipeline = const ['car', 'car-type', 'plate'];
  late List<_ImageAnalysis> _items;

  bool _halted = false;

  bool get _isHistoryView => widget.record != null;

  int _pageIndex = 0;
  int _tabIndex = 0;
  late final PageController _pageCtrl;
  late final AnimationController _scanCtrl;

  _ImageAnalysis get _current => _items[_pageIndex];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat();

    if (_isHistoryView) {
      _items = [_ImageAnalysis.fromRecord(widget.record!)];
    } else {
      final imgs = widget.images ?? [widget.image!];
      _items = imgs.map((f) => _ImageAnalysis(f)).toList();
      _analyzeAll();
    }
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyzeAll() async {
    String? firstValidPlate;

    for (final item in _items) {
      if (_halted) break;

      // Hata yakalama bloğu
      try {
        final readPlateText = await PlateReader.readPlate(item.image);
        final isPlateValid = readPlateText.isNotEmpty &&
            !readPlateText.toLowerCase().contains('bulunamadı') &&
            !readPlateText.toLowerCase().contains('hatası');

        if (isPlateValid) {
          if (firstValidPlate == null) {
            firstValidPlate = readPlateText;
          } else if (firstValidPlate != readPlateText) {

            if (!mounted) return;

            await _showPlateMismatchDialog();

            if (_halted) {
              if (mounted) {
                setState(() {
                  item.loading = false;
                  item.results['plate_text'] = {
                    'name': 'Okunan Plaka',
                    'label': 'İptal Edildi (Uyuşmazlık)',
                    'confidence': null
                  };
                });
              }
              break;
            }
          }
        }

        for (final base in _idPipeline) {
          if (_halted) break;
          final res = await Analyzer.run(base, item.image);
          if (mounted) setState(() => item.results[base] = res);
        }

        if (_halted) break;

        final parts = await Analyzer.detectAll('car-parts', item.image);
        final allDamages = await Analyzer.detectAll('damage', item.image);
        final damages = allDamages.where((d) => d.conf >= 50).toList();
        final report = DamageMatcher.match(parts, damages);

        if (mounted) {
          setState(() {
            item.parts = parts;
            item.damages = damages;
            item.damageReport = report;
            item.results['plate_text'] = {'name': 'Okunan Plaka', 'label': readPlateText, 'confidence': null};
            item.loading = false;
          });
        }

        if (!_halted) {
          await _saveToHistory(item);
          await _autoGenerateReport(item);
        }
      } catch (e) {
        debugPrint('Analiz sırasında hata oluştu: $e');
        if (mounted) {
          setState(() {
            item.loading = false;
            item.results['plate_text'] = {
              'name': 'Hata',
              'label': 'Analiz Başarısız',
              'confidence': null
            };
          });
        }
      }
    }

    if (_halted && mounted) {
      setState(() {
        for (var i in _items) {
          if (i.loading) {
            i.loading = false;
            i.results['plate_text'] = {'name': 'Durum', 'label': 'Analiz İptal Edildi', 'confidence': null};
          }
        }
      });
    }
  }

  // Sadece BİR TANE Dialog fonksiyonu bırakıldı
  Future<void> _showPlateMismatchDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Plaka Uyuşmazlığı'),
        content: const Text('Yüklediğiniz fotoğraflardaki araç plakaları birbiriyle eşleşmiyor. Farklı araçlara ait fotoğraflar yüklemiş olabilirsiniz.\n\nAnalize devam edilsin mi?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () {
              _halted = true;
              Navigator.pop(dialogCtx);
            },
            child: const Text('İptal Et'),
          ),
          TextButton(
            onPressed: () {
              _halted = false;
              Navigator.pop(dialogCtx);
            },
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToHistory(_ImageAnalysis item) async {
    try {
      final id = '${DateTime.now().millisecondsSinceEpoch}_${item.image.path.hashCode}';
      final docsDir = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${docsDir.path}/analysis_history');
      if (!await historyDir.exists()) await historyDir.create(recursive: true);
      final ext = item.image.path.split('.').last;
      final savedImage = await item.image.copy('${historyDir.path}/$id.$ext');

      final record = AnalysisRecord(
        id: id,
        imagePath: savedImage.path,
        createdAt: DateTime.now(),
        idResults: Map<String, Map<String, dynamic>>.from(item.results),
        parts: item.parts,
        damages: item.damages,
        damageReport: item.damageReport,
      );
      await HistoryStore.add(record);
    } catch (e) {
      debugPrint('Geçmişe kaydetme hatası: $e');
    }
  }

  // ------------------------------------------------------------------
  // PDF oluşturma ve paylaşma
  // ------------------------------------------------------------------

  String _plateLabel(_ImageAnalysis it) => (it.results['plate_text']?['label'] as String?) ?? 'Plaka bulunamadı';
  String _carLabel(_ImageAnalysis it) => (it.results['car']?['label'] as String?) ?? '-';
  String _carTypeLabel(_ImageAnalysis it) => (it.results['car-type']?['label'] as String?) ?? '-';

  pw.Page _buildPdfPage(_ImageAnalysis item, pw.MemoryImage pdfImage, bool isTr) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(isTr ? 'Oto Ekspertiz Raporu' : 'Auto Appraisal Report',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('${isTr ? 'Tarih' : 'Date'}: ${DateTime.now().toString().substring(0, 16)}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 16),
              pw.ClipRRect(
                horizontalRadius: 8,
                verticalRadius: 8,
                child: pw.Image(pdfImage, height: 220, fit: pw.BoxFit.cover),
              ),
              pw.SizedBox(height: 16),
              pw.Text('${isTr ? 'Araç' : 'Vehicle'}: ${_carLabel(item)}', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('${isTr ? 'Tip' : 'Type'}: ${_carTypeLabel(item)}', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('${isTr ? 'Plaka' : 'Plate'}: ${_plateLabel(item)}', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 16),
              pw.Text(isTr ? 'Hasar Durumu' : 'Damage Report',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              if (item.damageReport.isEmpty)
                pw.Text(isTr ? 'Hasar tespit edilmedi.' : 'No damages detected.',
                    style: const pw.TextStyle(fontSize: 11))
              else
                ...item.damageReport.map((line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text('• $line', style: const pw.TextStyle(fontSize: 11)),
                )),
              pw.Spacer(),
              pw.Divider(),
              pw.Text(isTr
                  ? 'Bu rapor yapay zeka destekli bir ön değerlendirmedir; resmi ekspertiz raporu yerine geçmez.'
                  : 'This report is an AI-supported preliminary assessment; it does not replace an official appraisal.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        );
      },
    );
  }

  Future<File> _buildPdf() async {
    final doc = pw.Document();
    final isTr = LanguageController.isTr;

    for (final item in _items) {
      final imageBytes = await item.image.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);
      doc.addPage(_buildPdfPage(item, pdfImage, isTr));
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${docsDir.path}/pdf_reports');
    if (!await reportsDir.exists()) await reportsDir.create(recursive: true);
    final file = File('${reportsDir.path}/oto_ekspertiz_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<void> _autoGenerateReport(_ImageAnalysis item) async {
    try {
      final isTr = LanguageController.isTr;
      final doc = pw.Document();
      final imageBytes = await item.image.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);
      doc.addPage(_buildPdfPage(item, pdfImage, isTr));

      final docsDir = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${docsDir.path}/pdf_reports');
      if (!await reportsDir.exists()) await reportsDir.create(recursive: true);
      final file = File(
          '${reportsDir.path}/oto_ekspertiz_${DateTime.now().millisecondsSinceEpoch}_${item.image.path.hashCode}.pdf');
      await file.writeAsBytes(await doc.save());

      await ReportsStore.add(ReportRecord(
        id: '${DateTime.now().millisecondsSinceEpoch}_${file.path.hashCode}',
        pdfPath: file.path,
        plateText: _plateLabel(item),
        carType: _carTypeLabel(item),
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('Otomatik rapor oluşturma hatası: $e');
    }
  }

  bool get _anyLoading => _items.any((i) => i.loading);
  bool _exporting = false;

  Future<void> _downloadPdf() async {
    if (_anyLoading || _exporting) return;
    setState(() => _exporting = true);
    try {
      final file = await _buildPdf();
      final firstItem = _items.first;
      await ReportsStore.add(ReportRecord(
        id: '${DateTime.now().millisecondsSinceEpoch}_${file.path.hashCode}',
        pdfPath: file.path,
        plateText: _plateLabel(firstItem),
        carType: _carTypeLabel(firstItem),
        createdAt: DateTime.now(),
      ));
      await Printing.sharePdf(bytes: await file.readAsBytes(), filename: file.path.split('/').last);
    } catch (e) {
      if (mounted) _showErrorToast('PDF oluşturulamadı: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareReport() async {
    if (_anyLoading) return;
    final item = _current;
    final summary = StringBuffer()
      ..writeln('Oto Ekspertiz Raporu')
      ..writeln('Araç: ${_carLabel(item)}  ·  Tip: ${_carTypeLabel(item)}')
      ..writeln('Plaka: ${_plateLabel(item)}')
      ..writeln(item.damageReport.isEmpty ? 'Hasar tespit edilmedi.' : item.damageReport.join('\n'));
    try {
      await Share.shareXFiles(_items.map((i) => XFile(i.image.path)).toList(), text: summary.toString());
    } catch (e) {
      if (mounted) _showErrorToast('Paylaşılamadı: $e');
    }
  }

  void _showErrorToast(String message) {
    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Tamam'))],
      ),
    );
  }

  // ------------------------------------------------------------------

  static const _icons = {
    'car': Icons.directions_car_rounded,
    'car-type': Icons.sell_rounded,
    'plate': Icons.confirmation_number_rounded,
    'plate_text': Icons.credit_card_rounded,
  };

  Color _confColor(BuildContext context, double? c) {
    final colors = context.colors;
    if (c == null) return colors.slate;
    if (c >= 70) return colors.leaf;
    if (c >= 40) return colors.amber;
    return colors.crimson;
  }

  Widget _confChip(BuildContext context, double? conf) {
    if (conf == null) return const SizedBox.shrink();
    final color = _confColor(context, conf);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
      child: Text('%${conf.toStringAsFixed(1)}',
          style: AppFonts.mono(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildVerdictCard(BuildContext context) {
    final c = context.colors;
    final item = _current;
    final v = _verdict(context, item);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.cardBorder),
        boxShadow: [
          BoxShadow(color: CupertinoColors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          VerdictGauge(
            value: v['value'] as double,
            color: v['color'] as Color,
            trackColor: c.cardBorder,
            label: v['text'] as String,
            icon: v['icon'] as IconData,
            size: 108,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageController.isTr ? 'Genel Değerlendirme' : 'Overall Assessment',
                  style: AppFonts.display(fontSize: 14, fontWeight: FontWeight.w700, color: c.navy),
                ),
                const SizedBox(height: 6),
                Text(
                  item.damageReport.isEmpty
                      ? (LanguageController.isTr
                      ? 'Fotoğrafta belirgin bir hasar tespit edilmedi.'
                      : 'No significant damage was detected in the photo.')
                      : (LanguageController.isTr
                      ? '${item.damageReport.length} adet hasar bölgesi tespit edildi.'
                      : '${item.damageReport.length} damaged area(s) detected.'),
                  style: TextStyle(fontSize: 12.5, color: c.slate, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDamageSection(BuildContext context) {
    final c = context.colors;
    final item = _current;
    if (item.loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }

    final Widget listPart;
    if (item.damageReport.isEmpty) {
      listPart = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.leaf.withOpacity(0.10), shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded, color: c.leaf, size: 32),
            ),
            const SizedBox(height: 14),
            Text('Hasar tespit edilmedi',
                style: AppFonts.display(color: c.navy, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('İncelenen görselde belirgin bir hasar bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.slate, fontSize: 13)),
          ],
        ),
      );
    } else {
      listPart = Column(
        children: item.damageReport.asMap().entries.map((entry) {
          final index = entry.key;
          final line = entry.value;
          final match = RegExp(r'%([\d.]+)').firstMatch(line);
          final conf = match != null ? double.tryParse(match.group(1)!) ?? 50.0 : 50.0;
          final sevColor = _confColor(context, conf);
          return FadeSlideIn(
            index: index,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.cardBorder),
                boxShadow: [
                  BoxShadow(color: CupertinoColors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withOpacity(0.72),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: sevColor.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Icon(Icons.warning_amber_rounded, color: sevColor, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(line, style: TextStyle(fontSize: 14, color: c.navy, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: [
        _buildVerdictCard(context),
        const SizedBox(height: 4),
        listPart,
      ],
    );
  }

  Map<String, dynamic> _verdict(BuildContext context, _ImageAnalysis item) {
    final c = context.colors;
    if (item.loading) {
      return {'text': 'Analiz Ediliyor', 'color': c.steel, 'icon': Icons.hourglass_top_rounded, 'value': 0.0};
    }
    if (item.damageReport.isEmpty) {
      return {'text': 'Temiz', 'color': c.leaf, 'icon': Icons.check_circle_rounded, 'value': 0.06};
    }
    if (item.damageReport.length <= 2) {
      return {'text': 'Hafif Hasarlı', 'color': c.amber, 'icon': Icons.error_outline_rounded, 'value': _severityValue(item)};
    }
    return {'text': 'Çoklu Hasar', 'color': c.crimson, 'icon': Icons.warning_amber_rounded, 'value': _severityValue(item)};
  }

  double _severityValue(_ImageAnalysis item) {
    if (item.damages.isEmpty) return 0.06;
    final avgConf = item.damages.map((d) => d.conf).reduce((a, b) => a + b) / item.damages.length;
    final countFactor = (item.damages.length / 6).clamp(0.0, 1.0);
    final confFactor = (avgConf / 100).clamp(0.0, 1.0);
    return (0.25 + 0.45 * countFactor + 0.30 * confFactor).clamp(0.15, 1.0);
  }

  Widget _segmentTab(AppColors c, {required IconData icon, required String label, required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? kInk : CupertinoColors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? CupertinoColors.white : c.slate),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected ? CupertinoColors.white : c.slate,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              c,
              icon: _exporting ? null : Icons.picture_as_pdf_rounded,
              label: _exporting ? 'Hazırlanıyor…' : 'PDF Oluştur',
              onTap: _anyLoading ? null : _downloadPdf,
              filled: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              c,
              icon: Icons.ios_share_rounded,
              label: 'Paylaş',
              onTap: _anyLoading ? null : _shareReport,
              filled: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(AppColors c,
      {IconData? icon, required String label, VoidCallback? onTap, required bool filled}) {
    final disabled = onTap == null;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: disabled ? c.cardBorder.withOpacity(0.4) : (filled ? kInk : c.cardBg),
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: c.cardBorder),
          boxShadow: filled && !disabled
              ? [BoxShadow(color: CupertinoColors.black.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: filled && !disabled ? CupertinoColors.white : c.navy),
              const SizedBox(width: 7),
            ] else
              const Padding(
                padding: EdgeInsets.only(right: 7),
                child: SizedBox(height: 14, width: 14, child: CupertinoActivityIndicator(radius: 7)),
              ),
            Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: filled && !disabled ? CupertinoColors.white : c.navy)),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbStrip(BuildContext context) {
    if (_items.length <= 1) return const SizedBox.shrink();
    final c = context.colors;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == _pageIndex;
          return GestureDetector(
            onTap: () => _pageCtrl.animateToPage(i,
                duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? kBrandAccent : c.cardBorder, width: selected ? 2.4 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_items[i].image, fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCarouselPage(BuildContext context, int i) {
    final c = context.colors;
    final item = _items[i];
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: CupertinoColors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(item.image, fit: BoxFit.cover),
              if (!item.loading && _tabIndex == 1)
                Positioned.fill(
                  child: DetectionOverlay(
                    parts: const [],
                    damages: item.damages,
                    partColor: c.steel,
                    damageColor: c.crimson,
                    showParts: false,
                    showDamages: true,
                  ),
                ),
              if (item.loading) ...[
                Container(color: CupertinoColors.black.withOpacity(0.45)),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _scanCtrl,
                    builder: (context, _) {
                      return Align(
                        alignment: Alignment(0, -1 + 2 * _scanCtrl.value),
                        child: Container(
                          width: double.infinity,
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [c.accent.withOpacity(0), c.accent, c.accent.withOpacity(0)],
                            ),
                            boxShadow: [BoxShadow(color: c.accent.withOpacity(0.7), blurRadius: 10)],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Center(child: CupertinoActivityIndicator(color: CupertinoColors.white, radius: 16)),
              ],
              if (_items.length > 1)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${i + 1}/${_items.length}',
                        style: AppFonts.mono(color: CupertinoColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String key, int index) {
    final c = context.colors;
    final item = _current;
    final result = item.results[key];

    final title = result?['name']?.toString() ?? key;
    final value = result?['label']?.toString() ?? '-';
    final conf = result?['confidence'] as double?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
        boxShadow: [
          BoxShadow(color: CupertinoColors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icons[key] ?? Icons.info_outline, color: c.accent, size: 24),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 12, color: c.slate)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              value,
              style: AppFonts.display(fontSize: 14, fontWeight: FontWeight.w600, color: c.navy),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conf != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _confChip(context, conf),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final idKeys = ['car', 'car-type', 'plate_text'];

    return CupertinoPageScaffold(
      backgroundColor: c.scaffoldBg,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isHistoryView ? 'Geçmiş Analiz' : 'Analiz Raporu'),
        backgroundColor: c.cardBg.withOpacity(0.94),
        border: Border(bottom: BorderSide(color: c.cardBorder, width: 0.5)),
        leading: Navigator.of(context).canPop()
            ? CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 24),
        )
            : null,
        trailing: _anyLoading
            ? null
            : CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _shareReport,
          child: Icon(Icons.ios_share_rounded, color: c.accent, size: 20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: SizedBox(
                height: 230,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _items.length,
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _buildCarouselPage(context, i),
                  ),
                ),
              ),
            ),
            if (_items.length > 1) ...[
              const SizedBox(height: 6),
              _buildThumbStrip(context),
            ],

            _buildActionBar(context),

            if (!_anyLoading && !_isHistoryView)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 13, color: c.leaf),
                    const SizedBox(width: 6),
                    Text('Bu analiz geçmişe otomatik kaydedildi', style: TextStyle(fontSize: 11.5, color: c.slate)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Row(
                  children: [
                    _segmentTab(c,
                        icon: Icons.badge_outlined,
                        label: 'Araç Bilgileri',
                        selected: _tabIndex == 0,
                        onTap: () => setState(() => _tabIndex = 0)),
                    const SizedBox(width: 4),
                    _segmentTab(c,
                        icon: Icons.directions_car_rounded,
                        label: 'Hasar Durumu',
                        selected: _tabIndex == 1,
                        onTap: () => setState(() => _tabIndex = 1)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _tabIndex == 0
                  ? GridView.count(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [for (int i = 0; i < idKeys.length; i++) _buildInfoTile(context, idKeys[i], i)],
              )
                  : ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                children: [_buildDamageSection(context)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}