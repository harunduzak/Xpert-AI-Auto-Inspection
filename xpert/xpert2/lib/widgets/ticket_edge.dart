import 'package:flutter/cupertino.dart';

/// Geçmiş listesindeki her kaydın durumunu gösteren sade renkli şerit.
/// (Sadeleştirilmiş sürüm — eski perforasyonlu "bilet kenarı" yerine
/// düz, ince bir durum çubuğu kullanılıyor.)
class TicketEdge extends StatelessWidget {
  final Color stripColor;
  /// Geriye dönük uyumluluk için tutulur; sade sürümde kullanılmıyor.
  final Color holeColor;
  final double width;

  const TicketEdge({
    super.key,
    required this.stripColor,
    required this.holeColor,
    this.width = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: stripColor,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      ),
    );
  }
}