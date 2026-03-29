import 'package:flutter_test/flutter_test.dart';
import 'package:focus_today/features/feed/presentation/utils/image_shape_type.dart';

void main() {
  group('classifyImageShapeFromAspectRatio', () {
    test('returns square within tolerance', () {
      expect(classifyImageShapeFromAspectRatio(1.0), ImageShapeType.square);
      expect(classifyImageShapeFromAspectRatio(0.95), ImageShapeType.square);
      expect(classifyImageShapeFromAspectRatio(1.06), ImageShapeType.square);
    });

    test('returns portrait when ratio < square threshold', () {
      expect(classifyImageShapeFromAspectRatio(0.7), ImageShapeType.portrait);
    });

    test('returns landscape when ratio > square threshold', () {
      expect(classifyImageShapeFromAspectRatio(1.4), ImageShapeType.landscape);
    });

    test('returns unknown for invalid ratio', () {
      expect(classifyImageShapeFromAspectRatio(0), ImageShapeType.unknown);
      expect(classifyImageShapeFromAspectRatio(-1), ImageShapeType.unknown);
      expect(
        classifyImageShapeFromAspectRatio(double.nan),
        ImageShapeType.unknown,
      );
    });
  });
}
