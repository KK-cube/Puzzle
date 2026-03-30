import 'package:flutter/material.dart';

import '../domain/models.dart';

extension TilePalette on TileColor {
  Color get fillColor {
    return switch (this) {
      TileColor.coral => const Color(0xFFF97360),
      TileColor.teal => const Color(0xFF14B8A6),
      TileColor.gold => const Color(0xFFFBBF24),
      TileColor.violet => const Color(0xFFA855F7),
      TileColor.mint => const Color(0xFF4ADE80),
    };
  }

  Color get edgeColor {
    return switch (this) {
      TileColor.coral => const Color(0xFFBE3D2F),
      TileColor.teal => const Color(0xFF0F766E),
      TileColor.gold => const Color(0xFFB7791F),
      TileColor.violet => const Color(0xFF7C3AED),
      TileColor.mint => const Color(0xFF15803D),
    };
  }
}
