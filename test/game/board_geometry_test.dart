import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game/domain/models.dart';
import 'package:flutter_application_1/game/presentation/board_geometry.dart';

void main() {
  group('BoardGeometry', () {
    test('points in the panel padding still map to the nearest edge cell', () {
      final geometry = BoardGeometry(const Size(420, 420));
      final point = Offset(
        geometry.boardRect.left - (geometry.outerPadding * 0.5),
        geometry.boardRect.top + (geometry.cellSize * 3.2),
      );

      expect(geometry.cellAt(point), const BoardPosition(3, 0));
    });

    test('column drag prefers the nearby slot before the exact midpoint', () {
      final geometry = BoardGeometry(const Size(420, 420));

      final offset = geometry.cellSize * 0.41;
      expect(geometry.nearestColumnForOffset(2, offset), 3);
    });

    test('row drag prefers the nearby slot before the exact midpoint', () {
      final geometry = BoardGeometry(const Size(420, 420));

      final offset = geometry.cellSize * 0.43;
      expect(geometry.nearestRowForOffset(2, offset), 3);
    });

    test('column drag is pulled toward the target slot when close enough', () {
      final geometry = BoardGeometry(const Size(420, 420));
      final rawOffset = geometry.cellSize * 0.84;

      final snappedOffset = geometry.snappedColumnOffset(2, rawOffset);

      expect(snappedOffset, greaterThan(rawOffset));
      expect(snappedOffset, lessThanOrEqualTo(geometry.cellSize));
    });

    test('row drag is pulled toward the target slot when close enough', () {
      final geometry = BoardGeometry(const Size(420, 420));
      final rawOffset = geometry.cellSize * 0.79;

      final snappedOffset = geometry.snappedRowOffset(2, rawOffset);

      expect(snappedOffset, greaterThan(rawOffset));
      expect(snappedOffset, lessThanOrEqualTo(geometry.cellSize));
    });

    test('row drag is clamped to the board edges', () {
      final geometry = BoardGeometry(const Size(420, 420));

      final offset = geometry.clampRowOffset(5, -(geometry.cellSize * 10));
      expect(offset, -5 * geometry.cellSize);
      expect(geometry.nearestRowForOffset(5, offset), 0);
    });
  });
}
