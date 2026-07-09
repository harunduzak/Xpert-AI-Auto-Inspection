// ==========================================
// dashboard_page.dart
// Ana sayfa: üstte arama + "Son Sorgular" (en son 3 analiz, geçmişin tamamı
// "Tümünü Gör" ile History sayfasında filtrelerle görülebilir), ortada
// "Yeni Ekspertiz Başlat" aksiyonu, altta ise oluşturulmuş PDF raporlarının
// listelendiği "Oluşturulan Raporlar" bölümü.
// ==========================================
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';
import '../core/language_controller.dart';
import '../core/analysis_record.dart';
import '../core/history_store.dart';
import '../core/reports_store.dart';
import 'report_page.dart';
import 'history_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<File> _selected = [];
  bool _busy = false;
  String _query = '';

  List<AnalysisRecord> _history = const [];
  List<ReportRecord> _reports = const [];

  bool _isReportSelectionMode = false;
  final Set<String> _selectedReportIds = {};

  static const int _recentLimit = 3;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _history = HistoryStore.getAll();
      _reports = ReportsStore.getAll();
      if (_reports.isEmpty) {
        _isReportSelectionMode = false;
        _selectedReportIds.clear();
      }
    });
  }

  // ---------------- Arama ----------------

  List<AnalysisRecord> get _filteredHistory {
    if (_query.trim().isEmpty) return _history;
    final q = _query.trim().toLowerCase();
    return _history.where((r) {
      // Araç modelindeki "_" işaretlerini boşluğa çevirerek arama yapıyoruz
      final carModelName = (r.idResults['car']?['label']?.toString() ?? r.carType).replaceAll('_', ' ').toLowerCase();
      return r.plateText.toLowerCase().contains(q) || carModelName.contains(q);
    }).toList();
  }

  // ---------------- Fotoğraf seçim mantığı ----------------

  Future<void> _pickGalleryMulti() async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 90);
      if (picked.isNotEmpty) {
        setState(() => _selected.addAll(picked.map((x) => File(x.path))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureCameraLoop() async {
    bool keepGoing = true;
    while (keepGoing) {
      final shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
      if (shot == null) break;
      setState(() => _selected.add(File(shot.path)));
      if (!mounted) return;
      keepGoing = await _askAnotherPhoto() ?? false;
    }
  }

  Future<bool?> _askAnotherPhoto() {
    final isTr = LanguageController.isTr;
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(isTr ? 'Fotoğraf Eklendi' : 'Photo Added'),
        content: Text(isTr ? 'Başka bir fotoğraf çekmek ister misiniz?' : 'Would you like to take another photo?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(isTr ? 'Bitir' : 'Finish'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(isTr ? 'Başka Çek' : 'Take Another'),
          ),
        ],
      ),
    );
  }

  void _removeAt(int i) => setState(() => _selected.removeAt(i));

  // --- MODERN TASARIMLI YENİ MENÜ ---
  // --- MODERN TASARIMLI YENİ MENÜ (DÜZELTİLDİ) ---
  void _showPicker(BuildContext context) {
    final isTr = LanguageController.isTr;
    final c = context.colors;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => Material( // Cupertino içinde hata vermemesi için Material ile sarıyoruz
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Üstteki küçük sürükleme (drag) çubuğu
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: c.slate.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Text(
                  isTr ? 'Fotoğraf Kaynağı' : 'Photo Source',
                  style: AppFonts.display(fontSize: 18, fontWeight: FontWeight.w700, color: c.navy),
                ),
                const SizedBox(height: 6),
                Text(
                  isTr
                      ? 'Analiz edilecek fotoğrafları nereden eklemek istersiniz?'
                      : 'Where would you like to add photos from?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.slate, fontSize: 13.5),
                ),
                const SizedBox(height: 24),

                // --- Kamera Seçeneği ---
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _captureCameraLoop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.scaffoldBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: kBrandAccent.withOpacity(0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: kBrandAccent, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(isTr ? 'Kamera' : 'Camera',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.navy)),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.slate, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- Galeri Seçeneği ---
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pickGalleryMulti();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.scaffoldBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: kBrandAccent.withOpacity(0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.photo_library_rounded, color: kBrandAccent, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(isTr ? 'Galeri' : 'Gallery',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.navy)),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.slate, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- Vazgeç Butonu ---
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: Text(
                    isTr ? 'Vazgeç' : 'Cancel',
                    style: TextStyle(color: c.slate, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToReport() {
    if (_selected.isEmpty) return;
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => ReportPage(images: List<File>.from(_selected))),
    ).then((_) {
      if (mounted) {
        setState(() => _selected.clear());
        _refreshData();
      }
    });
  }

  void _openRecord(AnalysisRecord r) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => ReportPage(image: File(r.imagePath), record: r)),
    ).then((_) {
      if (mounted) _refreshData();
    });
  }

  void _openHistoryPage() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => const HistoryPage()),
    ).then((_) => _refreshData());
  }

  // ---------------- Sorgu (analiz) silme (manuel) ----------------

  Future<void> _confirmDeleteRecord(AnalysisRecord r) async {
    final isTr = LanguageController.isTr;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(isTr ? 'Analizi Sil' : 'Delete Analysis'),
        content: Text(isTr
            ? '${r.plateText} plakalı analiz kaydı kalıcı olarak silinecek. Emin misiniz?'
            : 'The analysis record for ${r.plateText} will be permanently deleted. Are you sure?'),
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
      await HistoryStore.remove(r.id);
      if (mounted) _refreshData();
    }
  }

  // ---------------- Rapor Seçme ve Toplu Silme ----------------

  void _toggleReportSelectionMode() {
    setState(() {
      _isReportSelectionMode = !_isReportSelectionMode;
      _selectedReportIds.clear();
    });
  }

  void _toggleReportSelection(String id) {
    setState(() {
      if (_selectedReportIds.contains(id)) {
        _selectedReportIds.remove(id);
      } else {
        _selectedReportIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedReports(bool isTr) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(isTr ? 'Raporları Sil' : 'Delete Reports'),
        content: Text(isTr
            ? 'Seçili ${_selectedReportIds.length} raporu kalıcı olarak silmek istediğinize emin misiniz?'
            : 'Are you sure you want to permanently delete the ${_selectedReportIds.length} selected reports?'),
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
      for (final id in _selectedReportIds) {
        try {
          final r = _reports.firstWhere((rep) => rep.id == id);
          await ReportsStore.remove(id);
          final file = File(r.pdfPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isReportSelectionMode = false;
          _selectedReportIds.clear();
        });
        _refreshData();
      }
    }
  }

  Future<bool> _confirmDeleteReport(ReportRecord r) async {
    final isTr = LanguageController.isTr;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(isTr ? 'Raporu Sil' : 'Delete Report'),
        content: Text(isTr
            ? '${r.plateText} plakalı raporu kalıcı olarak silmek istediğinize emin misiniz?'
            : 'Are you sure you want to permanently delete the report for ${r.plateText}?'),
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
    return ok == true;
  }

  Future<void> _deleteReport(ReportRecord r) async {
    await ReportsStore.remove(r.id);
    try {
      final file = File(r.pdfPath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    if (mounted) _refreshData();
  }

  Future<void> _openReportPdf(ReportRecord r) async {
    final isTr = LanguageController.isTr;
    final file = File(r.pdfPath);
    if (!await file.exists()) {
      _showErrorToast(isTr ? 'PDF dosyası bulunamadı.' : 'PDF file not found.');
      _refreshData();
      return;
    }
    try {
      await Printing.sharePdf(bytes: await file.readAsBytes(), filename: file.path.split('/').last);
    } catch (e) {
      _showErrorToast(isTr ? 'PDF açılamadı: $e' : 'Could not open PDF: $e');
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

  // ---------------- Yardımcılar ----------------

  Map<String, dynamic> _verdictFor(BuildContext context, AnalysisRecord r, bool isTr) {
    final c = context.colors;
    if (r.damageReport.isEmpty) {
      return {'text': isTr ? 'Hasarsız' : 'No Damage', 'color': c.leaf, 'icon': Icons.verified_rounded};
    }
    if (r.damageReport.length <= 2) {
      return {'text': isTr ? 'Hafif Hasarlı' : 'Minor Damage', 'color': c.amber, 'icon': Icons.error_outline_rounded};
    }
    return {'text': isTr ? 'Çoklu Hasar' : 'Multiple Damage', 'color': c.crimson, 'icon': Icons.warning_amber_rounded};
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  // ---------------- UI ----------------

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
                  SliverToBoxAdapter(child: _buildHeader(c, isTr)),

                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      c,
                      isTr ? 'Son Sorgular' : 'Recent Inquiries',
                      onSeeAll: _history.isNotEmpty ? _openHistoryPage : null,
                      isTr: isTr,
                      topPadding: 10,
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildHistorySection(c, isTr)),

                  SliverToBoxAdapter(
                    child: _selected.isNotEmpty
                        ? _buildSelectionArea(c, isTr)
                        : _buildNewInspectionButton(c, isTr),
                  ),

                  SliverToBoxAdapter(child: _buildSearchBar(c, isTr)),

                  SliverToBoxAdapter(child: _buildReportsHeader(c, isTr)),
                  _buildReportsSliver(c, isTr),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
          );
        }
    );
  }

  Widget _buildHeader(AppColors c, bool isTr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kBrandAccent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.directions_car_filled_rounded, color: kBrandAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isTr ? 'HOŞ GELDİNİZ' : 'WELCOME',
                  style: AppFonts.mono(fontSize: 10.5, color: c.slate, fontWeight: FontWeight.w600, letterSpacing: 1.6)),
              const SizedBox(height: 1),
              Text('Xpert',
                  style: AppFonts.display(fontSize: 21, fontWeight: FontWeight.w800, color: c.navy, letterSpacing: -0.4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppColors c, bool isTr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: CupertinoSearchTextField(
        placeholder: isTr ? 'Plaka ile Ara' : 'Search by Plate / Model',
        backgroundColor: c.cardBg,
        style: TextStyle(color: c.navy, fontSize: 14),
        onChanged: (value) => setState(() => _query = value),
      ),
    );
  }

  Widget _buildNewInspectionButton(AppColors c, bool isTr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _busy ? null : () => _showPicker(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: kInk,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: kInk.withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_busy)
                const SizedBox(height: 16, width: 16, child: CupertinoActivityIndicator(color: kBrandAccent, radius: 8))
              else
                const Icon(Icons.add_photo_alternate_rounded, color: kBrandAccent, size: 19),
              const SizedBox(width: 9),
              Text(
                isTr ? 'Aracını Sorgula' : 'Start New Inspection',
                style: const TextStyle(color: CupertinoColors.white, fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionArea(AppColors c, bool isTr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSelectedStrip(c),
          const SizedBox(height: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _goToReport,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: kInk,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: kInk.withOpacity(0.22), blurRadius: 16, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: kBrandAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(isTr ? '${_selected.length} Fotoğrafı Analiz Et' : 'Analyze ${_selected.length} Photos',
                      style: const TextStyle(color: CupertinoColors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedStrip(AppColors c) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selected.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == _selected.length) {
            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showPicker(context),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBrandAccent.withOpacity(0.4), width: 1.4),
                ),
                child: Icon(Icons.add_rounded, color: kBrandAccentDeep, size: 26),
              ),
            );
          }
          final file = _selected[i];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(file, width: 76, height: 76, fit: BoxFit.cover),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 22,
                  onPressed: () => _removeAt(i),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: CupertinoColors.black, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: CupertinoColors.white, size: 14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(AppColors c, String title,
      {VoidCallback? onSeeAll, bool isTr = true, double topPadding = 18}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppFonts.display(fontSize: 16.5, fontWeight: FontWeight.w700, color: c.navy)),
          if (onSeeAll != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: onSeeAll,
              child: Text(isTr ? 'Tümünü Gör' : 'See All',
                  style: TextStyle(fontSize: 13, color: c.accent, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildReportsHeader(AppColors c, bool isTr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isTr ? 'Oluşturulan Raporlar' : 'Generated Reports',
              style: AppFonts.display(fontSize: 16.5, fontWeight: FontWeight.w700, color: c.navy)),
          if (_reports.isNotEmpty)
            Row(
              children: [
                if (_isReportSelectionMode && _selectedReportIds.isNotEmpty) ...[
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: () => _deleteSelectedReports(isTr),
                    child: Text(isTr ? 'Sil (${_selectedReportIds.length})' : 'Delete (${_selectedReportIds.length})',
                        style: TextStyle(fontSize: 13, color: c.crimson, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 14),
                ],
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: _toggleReportSelectionMode,
                  child: Text(
                      _isReportSelectionMode
                          ? (isTr ? 'Vazgeç' : 'Cancel')
                          : (isTr ? 'Seç' : 'Select'),
                      style: TextStyle(fontSize: 13, color: c.accent, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(AppColors c, bool isTr) {
    final records = _filteredHistory;

    if (_history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _placeholderCard(
          c,
          icon: Icons.history_rounded,
          text: isTr ? 'Henüz analiz geçmişiniz yok' : 'No analysis history yet',
        ),
      );
    }

    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _placeholderCard(
          c,
          icon: Icons.search_off_rounded,
          text: isTr ? '"$_query" ile eşleşen bir kayıt yok' : 'No records matching "$_query"',
        ),
      );
    }

    final shown = records.take(_recentLimit).toList();

    return SizedBox(
      height: 198,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _historyCard(context, c, shown[i], isTr),
      ),
    );
  }

  Widget _historyCard(BuildContext context, AppColors c, AnalysisRecord r, bool isTr) {
    final v = _verdictFor(context, r, isTr);
    final imageFile = File(r.imagePath);

    // "_" işaretini boşluğa çevirerek gerçek model adını çekiyoruz (örn: Fiat Linea)
    final carModelName = (r.idResults['car']?['label']?.toString() ?? r.carType).replaceAll('_', ' ');

    return GestureDetector(
      onTap: () => _openRecord(r),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 152,
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.cardBorder),
              boxShadow: [
                BoxShadow(color: CupertinoColors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 84,
                  width: double.infinity,
                  child: imageFile.existsSync()
                      ? Image.file(imageFile, fit: BoxFit.cover)
                      : Container(
                    color: c.cardBorder,
                    child: Icon(Icons.directions_car_rounded, color: c.slate, size: 30),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(carModelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.display(fontSize: 13, fontWeight: FontWeight.w700, color: c.navy)),
                      const SizedBox(height: 5),
                      Text(isTr ? 'Plaka' : 'Plate',
                          style: TextStyle(fontSize: 9.5, color: c.slate, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.plateText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.mono(fontSize: 12.5, color: c.navy, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: (v['color'] as Color).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(v['text'] as String,
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: v['color'] as Color)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${isTr ? 'Ekspertiz' : 'Inspection'}: ${_formatDate(r.createdAt)}',
                          style: TextStyle(fontSize: 9.5, color: c.slate)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 22,
              onPressed: () => _confirmDeleteRecord(r),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: CupertinoColors.black, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: CupertinoColors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsSliver(AppColors c, bool isTr) {
    if (_reports.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _placeholderCard(
            c,
            icon: Icons.picture_as_pdf_rounded,
            text: isTr ? 'Henüz oluşturulmuş bir PDF rapor yok' : 'No PDF reports generated yet',
          ),
        ),
      );
    }

    final sorted = List<ReportRecord>.from(_reports)
      ..sort((a, b) {
        final byPlate = a.plateText.toUpperCase().compareTo(b.plateText.toUpperCase());
        if (byPlate != 0) return byPlate;
        return b.createdAt.compareTo(a.createdAt);
      });

    final List<Widget> rows = [];
    String? lastPlate;
    for (final r in sorted.take(30)) {
      if (r.plateText != lastPlate) {
        if (lastPlate != null) rows.add(const SizedBox(height: 12));
        rows.add(_plateGroupHeader(c, r.plateText));
        lastPlate = r.plateText;
      }

      if (_isReportSelectionMode) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _reportRow(c, r, isTr),
        ));
      } else {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Dismissible(
            key: ValueKey(r.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDeleteReport(r),
            onDismissed: (_) => _deleteReport(r),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(color: c.crimson, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.delete_rounded, color: CupertinoColors.white),
            ),
            child: _reportRow(c, r, isTr),
          ),
        ));
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(delegate: SliverChildListDelegate(rows)),
    );
  }

  Widget _plateGroupHeader(AppColors c, String plate) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, left: 2),
      child: Row(
        children: [
          Icon(Icons.confirmation_number_rounded, size: 13, color: c.steel),
          const SizedBox(width: 6),
          Text(plate,
              style: AppFonts.mono(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.navy, letterSpacing: 0.8)),
        ],
      ),
    );
  }

  Widget _reportRow(AppColors c, ReportRecord r, bool isTr) {
    final isSelected = _selectedReportIds.contains(r.id);

    // Eşleşen analiz kaydını plakadan bularak "_" olmadan gerçek model adını çekiyoruz
    String carModelName = r.carType.replaceAll('_', ' '); // Fallback
    try {
      final match = _history.firstWhere((hist) => hist.plateText == r.plateText);
      carModelName = (match.idResults['car']?['label']?.toString() ?? r.carType).replaceAll('_', ' ');
    } catch (_) {}

    return GestureDetector(
      onTap: () {
        if (_isReportSelectionMode) {
          _toggleReportSelection(r.id);
        } else {
          _openReportPdf(r);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? c.accent.withOpacity(0.08) : c.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? c.accent : c.cardBorder, width: isSelected ? 1.5 : 1.0),
          boxShadow: [
            if (!isSelected)
              BoxShadow(color: CupertinoColors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            if (_isReportSelectionMode) ...[
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? c.accent : c.slate.withOpacity(0.5),
                size: 22,
              ),
              const SizedBox(width: 12),
            ],
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: c.crimson.withOpacity(0.10), borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.picture_as_pdf_rounded, color: c.crimson, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(carModelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.display(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.navy)),
                  const SizedBox(height: 3),
                  Text(_formatDate(r.createdAt), style: TextStyle(fontSize: 11.5, color: c.slate)),
                ],
              ),
            ),
            if (!_isReportSelectionMode)
              Icon(Icons.ios_share_rounded, color: c.accent, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _placeholderCard(AppColors c, {required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: c.slate, size: 26),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: c.slate, fontSize: 12.5)),
        ],
      ),
    );
  }
}