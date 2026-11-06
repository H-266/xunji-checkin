/// 自定义标签。
///
/// 标签只用于今日列表筛选和展示，不参与热力统计口径，
/// 因此不会改变“一个格子 = 一整天”的全局热力规则。
class Tag {
  final int? id;
  final String name;

  /// ARGB 颜色值；由创建时在一组低饱和色板中轮换选取。
  final int color;
  final int createdAt;

  /// 常用标签置顶；列表按 pinned 倒序、创建时间倒序。
  final bool pinned;

  const Tag({
    this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    this.pinned = false,
  });

  factory Tag.fromMap(Map<String, Object?> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      color: map['color'] as int? ?? 0xFF3B6FD4,
      createdAt: map['created_at'] as int? ?? 0,
      pinned: (map['pinned'] as int? ?? 0) != 0,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt,
      'pinned': pinned ? 1 : 0,
    };
  }

  Tag copyWith({
    int? id,
    String? name,
    int? color,
    int? createdAt,
    bool? pinned,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      pinned: pinned ?? this.pinned,
    );
  }

  @override
  String toString() => 'Tag(id: $id, name: $name)';
}
