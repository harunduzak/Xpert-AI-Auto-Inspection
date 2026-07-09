// ==========================================
// history_page.dart
// ==========================================
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../core/analysis_record.dart';
import '../core/history_store.dart';
import '../core/reports_store.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/ticket_edge.dart';
import '../core/language_controller.dart';
import 'report_page.dart';

enum _DamageFilter { all, none, light, heavy }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late List<AnalysisRecord> _allRecords;
  String _query = '';
  _DamageFilter _damageFilter = _DamageFilter.all;
  String? _makeFilter; // seçili araç tipi/model filtresi (null = hepsi)

  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _allRecords = HistoryStore.getAll();
  }

  void _refresh() => setState(() => _allRecords = HistoryStore.getAll());

  // ---------------- Seçim modu ----------------

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final isTr = LanguageController.isTr;
    if (_selectedIds.isEmpty) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text(isTr ? 'Seçilenleri Sil' : 'Delete Selected'),
        content: Text(isTr
            ? '${_selectedIds.length} kayıt kalıcı olarak silinecek. Emin misiniz?'
            : '${_selectedIds.length} record(s) will be permanently deleted. Are you sure?'),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(isTr ? 'Vazgeç' : 'Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(isTr ? 'Sil' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final id in _selectedIds.toList()) {
        await HistoryStore.remove(id);
      }
      _selectedIds.clear();
      _selectionMode = false;
      _refresh();
    }
  }

  Future<void> _delete(AnalysisRecord r) async {
    await HistoryStore.remove(r.id);
    _refresh();
  }

  Future<void> _confirmClearAll() async {
    final isTr = LanguageController.isTr;
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
              child: Text(isTr ? 'Vazgeç' : 'Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(isTr ? 'Sil' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Settings sayfasındaki "Geçmişi Temizle" ile aynı davranış:
      // geçmişle birlikte oluşturulmuş tüm PDF raporları da silinir.
      final reports = ReportsStore.getAll();
      for (final r in reports) {
        try {
          final file = File(r.pdfPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      await ReportsStore.clear();
      await HistoryStore.clear();
      _refresh();
    }
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} · ${two(d.hour)}:${two(d.minute)}';
  }

  // ---------------- Hasar kategorisi (filtre + rozet için tek kaynak) ----------------

  _DamageFilter _categoryOf(AnalysisRecord r) {
    if (r.damageReport.isEmpty) return _DamageFilter.none;
    if (r.damageReport.length <= 2) return _DamageFilter.light;
    return _DamageFilter.heavy;
  }

  List<String> get _availableMakes {
    final set = _allRecords.map((r) => (r.idResults['car']?['label']?.toString() ?? r.carType).replaceAll('_', ' ')).where((s) => s.trim().isNotEmpty).toSet().toList();
    set.sort();
    return set;
  }

  /// Arama + hasar filtresi + marka/model filtresi birlikte uygulanır.
  List<AnalysisRecord> get _filteredRecords {
    Iterable<AnalysisRecord> list = _allRecords;

    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list.where((r) {
        final plate = r.plateText.toLowerCase();
        final date = _formatDate(r.createdAt).toLowerCase();
        final makeModel = (r.idResults['car']?['label']?.toString() ?? r.carType).replaceAll('_', ' ').toLowerCase();
        return plate.contains(q) || date.contains(q) || makeModel.contains(q);
      });
    }

    if (_damageFilter != _DamageFilter.all) {
      list = list.where((r) => _categoryOf(r) == _damageFilter);
    }

    if (_makeFilter != null) {
      list = list.where((r) => (r.idResults['car']?['label']?.toString() ?? r.carType).replaceAll('_', ' ') == _makeFilter);
    }

    return list.toList();
  }

  Map<String, dynamic> _verdictFor(BuildContext context, AnalysisRecord r, bool isTr) {
    final c = context.colors;
    switch (_categoryOf(r)) {
      case _DamageFilter.none:
        return {'text': isTr ? 'Temiz' : 'Clean', 'color': c.leaf, 'icon': Icons.verified_rounded};
      case _DamageFilter.light:
        return {'text': isTr ? 'Hafif Hasarlı' : 'Minor Damage', 'color': c.amber, 'icon': Icons.error_outline_rounded};
      case _DamageFilter.heavy:
      case _DamageFilter.all:
        return {'text': isTr ? 'Çoklu Hasar' : 'Severe Damage', 'color': c.crimson, 'icon': Icons.warning_amber_rounded};
    }
  }

  // ---------------- UI parçaları ----------------

  /// Sayfa bir route olarak (Navigator.push) açıldıysa elle, garanti bir geri
  /// oku gösterir. Sekme kökü olarak açıldıysa (pop edilemiyorsa) hiçbir şey
  /// göstermez — böylece kırık/soluk ikon riski ortadan kalkar.
  Widget? _backLeading(BuildContext context) {
    if (!Navigator.of(context).canPop()) return null;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: () => Navigator.of(context).pop(),
      // CupertinoIcons.back yerine Icons kullanıldı
      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 24),
    );
  }

  Widget _filterChip(AppColors c, {required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kInk : c.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kInk : c.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? CupertinoColors.white : c.slate,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(AppColors c, bool isTr) {
    final makes = _availableMakes;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _filterChip(
            c,
            label: isTr ? 'Tümü' : 'All',
            selected: _damageFilter == _DamageFilter.all,
            onTap: () => setState(() => _damageFilter = _DamageFilter.all),
          ),
          const SizedBox(width: 8),
          _filterChip(
            c,
            label: isTr ? 'Hasarsız' : 'Undamaged',
            selected: _damageFilter == _DamageFilter.none,
            onTap: () => setState(() => _damageFilter = _DamageFilter.none),
          ),
          const SizedBox(width: 8),
          _filterChip(
            c,
            label: isTr ? 'Hafif Hasarlı' : 'Light Damage',
            selected: _damageFilter == _DamageFilter.light,
            onTap: () => setState(() => _damageFilter = _DamageFilter.light),
          ),
          const SizedBox(width: 8),
          _filterChip(
            c,
            label: isTr ? 'Ağır Hasarlı' : 'Heavy Damage',
            selected: _damageFilter == _DamageFilter.heavy,
            onTap: () => setState(() => _damageFilter = _DamageFilter.heavy),
          ),
          if (makes.isNotEmpty) ...[
            Container(width: 1, height: 22, color: c.cardBorder, margin: const EdgeInsets.symmetric(horizontal: 8)),
            for (final make in makes) ...[
              _filterChip(
                c,
                label: make,
                selected: _makeFilter == make,
                onTap: () => setState(() => _makeFilter = _makeFilter == make ? null : make),
              ),
              const SizedBox(width: 8),
            ],
          ],
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
          final records = _filteredRecords;
          final hasAnyHistory = _allRecords.isNotEmpty;
          final hasSearchResults = records.isNotEmpty;

          return CupertinoPageScaffold(
            backgroundColor: c.scaffoldBg,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        CupertinoSliverNavigationBar(
                          leading: _backLeading(context),
                          largeTitle: Text(isTr ? 'Geçmiş' : 'History'),
                          backgroundColor: c.cardBg.withOpacity(0.94),
                          border: Border(bottom: BorderSide(color: c.cardBorder, width: 0.5)),
                          trailing: hasAnyHistory
                              ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _toggleSelectionMode,
                            child: Text(
                              _selectionMode
                                  ? (isTr ? 'İptal' : 'Cancel')
                                  : (isTr ? 'Seç' : 'Select'),
                              style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
                            ),
                          )
                              : null,
                        ),

                        if (hasAnyHistory)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                              child: CupertinoSearchTextField(
                                placeholder: isTr ? 'Plaka veya tarihe göre ara…' : 'Search by plate or date...',
                                backgroundColor: c.cardBg,
                                style: TextStyle(color: c.navy, fontSize: 14),
                                onChanged: (value) => setState(() => _query = value),
                              ),
                            ),
                          ),

                        if (hasAnyHistory)
                          SliverToBoxAdapter(child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _buildFilterRow(c, isTr),
                          )),

                        if (!hasAnyHistory)
                          SliverFillRemaining(hasScrollBody: false, child: _EmptyState(color: c, isTr: isTr))
                        else if (!hasSearchResults)
                          SliverFillRemaining(
                              hasScrollBody: false,
                              child: _NoSearchResultsState(color: c, query: _query, isTr: isTr))
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                  final r = records[index];
                                  final v = _verdictFor(context, r, isTr);
                                  final imageFile = File(r.imagePath);
                                  final selected = _selectedIds.contains(r.id);

                                  final card = Container(
                                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: c.cardBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: selected ? c.accent : c.cardBorder,
                                        width: selected ? 1.6 : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          TicketEdge(stripColor: v['color'] as Color, holeColor: c.cardBg),
                                          if (_selectionMode)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 10),
                                              child: Center(
                                                child: Icon(
                                                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                                  color: selected ? c.accent : c.slate,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Row(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: SizedBox(
                                                      width: 60,
                                                      height: 60,
                                                      child: imageFile.existsSync()
                                                          ? Image.file(imageFile, fit: BoxFit.cover)
                                                          : Container(
                                                        color: c.cardBorder,
                                                        child: Icon(Icons.image_outlined, color: c.slate),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text((r.idResults['car']?['label']?.toString() ?? r.carType).replaceAll('_', ' ').toUpperCase(), style: AppFonts.display(fontSize: 15.5, fontWeight: FontWeight.w600, color: c.navy)),
                                                        const SizedBox(height: 3),
                                                        Text(r.plateText,
                                                            style: AppFonts.mono(
                                                                fontSize: 12,
                                                                color: c.slate,
                                                                fontWeight: FontWeight.w600,
                                                                letterSpacing: 1)),
                                                        const SizedBox(height: 4),
                                                        Text(_formatDate(r.createdAt),
                                                            style: TextStyle(fontSize: 11.5, color: c.slate)),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: (v['color'] as Color).withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(v['icon'] as IconData,
                                                            size: 13, color: v['color'] as Color),
                                                        const SizedBox(width: 4),
                                                        Text(v['text'] as String,
                                                            style: TextStyle(
                                                                fontSize: 11.5,
                                                                fontWeight: FontWeight.w700,
                                                                color: v['color'] as Color)),
                                                      ],
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

                                  return FadeSlideIn(
                                    index: index,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        if (_selectionMode) {
                                          _toggleSelected(r.id);
                                          return;
                                        }
                                        Navigator.of(context, rootNavigator: true).push(
                                          CupertinoPageRoute(
                                              builder: (_) => ReportPage(image: imageFile, record: r)),
                                        );
                                      },
                                      child: _selectionMode
                                          ? card
                                          : Dismissible(
                                        key: ValueKey(r.id),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 24),
                                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                                          decoration: BoxDecoration(
                                              color: c.crimson, borderRadius: BorderRadius.circular(16)),
                                          child: const Icon(Icons.delete_rounded, color: CupertinoColors.white),
                                        ),
                                        onDismissed: (_) => _delete(r),
                                        child: card,
                                      ),
                                    ),
                                  );
                                },
                                childCount: records.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // --- Toplu silme alt barı (seçim modunda) ---
                  if (_selectionMode)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                      decoration: BoxDecoration(
                        color: c.cardBg,
                        border: Border(top: BorderSide(color: c.cardBorder)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                isTr ? '${_selectedIds.length} seçildi' : '${_selectedIds.length} selected',
                                style: TextStyle(color: c.slate, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (hasAnyHistory)
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _confirmClearAll,
                                child: Text(isTr ? 'Tümünü Temizle' : 'Clear All',
                                    style: TextStyle(color: c.slate, fontSize: 13)),
                              ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              color: _selectedIds.isEmpty ? c.cardBorder : c.crimson,
                              borderRadius: BorderRadius.circular(14),
                              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                              child: Text(isTr ? 'Sil' : 'Delete',
                                  style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        });
  }
}

/// Hiç geçmiş kaydı yokken gösterilen boş durum.
class _EmptyState extends StatelessWidget {
  final AppColors color;
  final bool isTr;
  const _EmptyState({required this.color, required this.isTr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: color.steel.withOpacity(0.10), shape: BoxShape.circle),
              child: Icon(Icons.history_rounded, color: color.steel, size: 36),
            ),
            const SizedBox(height: 16),
            Text(isTr ? 'Henüz analiz geçmişiniz yok' : 'No analysis history yet',
                style: AppFonts.display(color: color.navy, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(isTr
                ? 'Yeni bir analiz yaptığınızda burada listelenecek.'
                : 'When you make a new analysis, it will be listed here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: color.slate, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Geçmiş kayıtlar var ama arama/filtre ile eşleşen bulunamadığında gösterilir.
class _NoSearchResultsState extends StatelessWidget {
  final AppColors color;
  final String query;
  final bool isTr;
  const _NoSearchResultsState({required this.color, required this.query, required this.isTr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: color.slate.withOpacity(0.10), shape: BoxShape.circle),
              child: Icon(Icons.search_off_rounded, color: color.slate, size: 36),
            ),
            const SizedBox(height: 16),
            Text(isTr ? 'Kayıt bulunamadı' : 'No records found',
                style: AppFonts.display(color: color.navy, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
                query.trim().isEmpty
                    ? (isTr ? 'Seçili filtrelerle eşleşen kayıt yok.' : 'No records match the selected filters.')
                    : (isTr
                    ? '"$query" ile eşleşen bir plaka veya tarih yok.'
                    : 'No plate or date matching "$query" found.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: color.slate, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}