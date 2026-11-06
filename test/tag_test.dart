import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/models/tag.dart';

void main() {
  group('标签模型', () {
    test('默认不置顶，数据库默认值兼容旧数据', () {
      final tag = Tag.fromMap({
        'id': 7,
        'name': '健康',
        'color': 0xFF3B6FD4,
        'created_at': 100,
      });
      expect(tag.pinned, isFalse);
      expect(tag.toMap()['pinned'], 0);
    });

    test('置顶字段往返数据库', () {
      const tag = Tag(
        id: 1,
        name: '成长',
        color: 0xFF3B6FD4,
        createdAt: 10,
        pinned: true,
      );
      final restored = Tag.fromMap(tag.toMap());
      expect(restored.pinned, isTrue);
      expect(restored.name, '成长');
      expect(restored.id, 1);
    });

    test('copyWith 可取消置顶并保留其他字段', () {
      const tag = Tag(
        id: 2,
        name: '阅读',
        color: 0xFF8866CC,
        createdAt: 20,
        pinned: true,
      );
      final updated = tag.copyWith(pinned: false);
      expect(updated.pinned, isFalse);
      expect(updated.name, '阅读');
      expect(updated.color, 0xFF8866CC);
      expect(updated.createdAt, 20);
    });

    test('空名称不会被模型层伪造为非空', () {
      final tag = Tag.fromMap({'name': null});
      expect(tag.name, isEmpty);
    });
  });
}
