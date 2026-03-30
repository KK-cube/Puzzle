import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game/presentation/board_geometry.dart';

void main() {
  group('BoardGeometry', () {
    test('column drag snaps to the nearest target slot', () {
      final geometry = BoardGeometry(const Size(420, 420));

      final offset = geometry.clampColumnOffset(2, geometry.cellSize * 1.4);
      expect(geometry.nearestColumnForOffset(2, offset), 4);
    });

    test('row drag is clamped to the board edges', () {
      final geometry = BoardGeometry(const Size(420, 420));

      final offset = geometry.clampRowOffset(5, -(geometry.cellSize * 10));
      expect(offset, -5 * geometry.cellSize);
      expect(geometry.nearestRowForOffset(5, offset), 0);
    });
  });
}
