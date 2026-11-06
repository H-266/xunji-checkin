import 'dart:ui' show Locale;

import 'app_strings_en.dart';
import 'app_strings_es.dart';
import 'app_strings_extra.dart';
import 'app_strings_generated.dart';
import 'app_strings_fr.dart';
import 'app_strings_ja.dart';
import 'app_strings_long.dart';
import 'app_strings_stats.dart';
import 'zh_hant.dart';

/// 轻量运行时文案表。
///
/// 页面骨架仍使用 ARB/`AppLocalizations`；这里用于承接正文、弹窗、
/// 空状态等需要随语言即时切换的历史硬编码文案。未录入的条目先回退
/// 到英文，英文也没有时回退中文，保证不会出现空白。
class AppStrings {
  AppStrings._();

  static String languageCode = 'zh';

  /// 把 Flutter 的 Locale 收敛成项目内的文案代码。
  /// `zh_Hant` 的 languageCode 仍是 `zh`，必须看 script/region，
  /// 否则繁体页面会被当成简体，const LText 也不会换 key 重挂载。
  static String codeForLocale(Locale locale) {
    if (locale.languageCode == 'zh') {
      final script = locale.scriptCode?.toUpperCase();
      final region = locale.countryCode?.toUpperCase();
      if (script == 'HANT' ||
          region == 'TW' ||
          region == 'HK' ||
          region == 'MO') {
        return 'zh_Hant';
      }
    }
    return locale.languageCode;
  }

  static const Map<String, Map<String, String>> _maps = {
    'en': enStrings,
    'ja': jaStrings,
    'fr': frStrings,
    'es': esStrings,
  };

  static const Map<String, Map<String, String>> _uiStrings = {
    'en': {
      '暗夜蓝': 'Midnight Blue',
      '森绿': 'Forest Green',
      '赭石': 'Ochre',
      '莫兰迪粉': 'Morandi Pink',
      '深空灰': 'Space Gray',
      '落日橙': 'Sunset Orange',
      '无标签': 'No tag',
      '仅 Android': 'Android only',
      '周期': 'Cycle',
      '保存中…': 'Saving…',
    },
    'ja': {
      '暗夜蓝': 'ミッドナイトブルー',
      '森绿': 'フォレストグリーン',
      '赭石': 'オーカー',
      '莫兰迪粉': 'モランディピンク',
      '深空灰': 'スペースグレー',
      '落日橙': 'サンセットオレンジ',
      '无标签': 'タグなし',
      '仅 Android': 'Android のみ',
      '周期': 'サイクル',
      '保存中…': '保存中…',
    },
    'fr': {
      '暗夜蓝': 'Bleu nuit',
      '森绿': 'Vert forêt',
      '赭石': 'Ocre',
      '莫兰迪粉': 'Rose Morandi',
      '深空灰': 'Gris spatial',
      '落日橙': 'Orange coucher de soleil',
      '无标签': 'Sans tag',
      '仅 Android': 'Android uniquement',
      '周期': 'Cycle',
      '保存中…': 'Enregistrement…',
    },
    'es': {
      '暗夜蓝': 'Azul noche',
      '森绿': 'Verde bosque',
      '赭石': 'Ocre',
      '莫兰迪粉': 'Rosa Morandi',
      '深空灰': 'Gris espacial',
      '落日橙': 'Naranja atardecer',
      '无标签': 'Sin etiqueta',
      '仅 Android': 'Solo Android',
      '周期': 'Ciclo',
      '保存中…': 'Guardando…',
    },
  };

  static bool get isChinese =>
      languageCode == 'zh' || languageCode == 'zh_Hant';

  /// 周一..周日，用于热力图表头、星期选择、长图。
  static const Map<String, List<String>> _weekdays = {
    'zh': ['一', '二', '三', '四', '五', '六', '日'],
    'zh_Hant': ['一', '二', '三', '四', '五', '六', '日'],
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'ja': ['月', '火', '水', '木', '金', '土', '日'],
    'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
    'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
  };

  static String weekdayShort(int index) {
    final list = _weekdays[languageCode] ?? _weekdays['zh']!;
    return list[index.clamp(0, 6)];
  }

  /// 导出文件名前缀：中文环境使用中文名，其余语言用稳定 ASCII 名。
  static String get exportPrefix {
    return switch (languageCode) {
      'zh' => '循记打卡',
      'zh_Hant' => '循記打卡',
      'ja' => '循記打卡',
      _ => 'xunji-checkin',
    };
  }

  /// 批量页/回收站的选择计数。
  static String selectedCount(int n) {
    return switch (languageCode) {
      'en' => '$n selected',
      'ja' => '$n件選択',
      'fr' => '$n sélectionné(s)',
      'es' => '$n seleccionado(s)',
      'zh_Hant' => '已選 $n 項',
      _ => '已选 $n 项',
    };
  }

  /// 提醒时间的可读文案。
  static String dailyAt(String time) {
    return switch (languageCode) {
      'en' => 'Daily at $time',
      'ja' => '毎日 $time',
      'fr' => 'Tous les jours à $time',
      'es' => 'Todos los días a las $time',
      'zh_Hant' => '每天 $time',
      _ => '每天 $time',
    };
  }

  static String tr(String zh) {
    if (languageCode == 'zh') return zh;
    if (languageCode == 'zh_Hant') return toTraditionalChinese(zh);
    final generated = switch (languageCode) {
      'en' => generatedEn,
      'ja' => generatedJa,
      'fr' => generatedFr,
      'es' => generatedEs,
      _ => const <String, String>{},
    };
    final direct =
        _maps[languageCode]?[zh] ??
        extraStrings[languageCode]?[zh] ??
        longStrings[languageCode]?[zh] ??
        statsStrings[languageCode]?[zh] ??
        _uiStrings[languageCode]?[zh] ??
        generated[zh] ??
        enStrings[zh] ??
        extraStrings['en']?[zh] ??
        generatedEn[zh];
    if (direct != null) return direct;
    final patterned = _pattern(zh);
    if (patterned != null) return patterned;
    return zh;
  }

  /// 常见错误提示前缀的本地化，避免为每个拼接错误单独建 key。
  static String? _errorPrefix(String zh) {
    final en = switch (zh) {
      '回滚失败' => 'Rollback failed',
      '选择目录失败' => 'Could not select folder',
      '备份失败' => 'Backup failed',
      '批量操作失败' => 'Batch action failed',
      '导出失败' => 'Export failed',
      '保存图片失败' => 'Could not save image',
      '操作失败' => 'Action failed',
      'CSV 导出失败' => 'CSV export failed',
      '备份校验失败' => 'Backup validation failed',
      '导入失败' => 'Import failed',
      '撤销失败' => 'Undo failed',
      '添加失败' => 'Add failed',
      _ => null,
    };
    if (en == null) return null;
    return switch (languageCode) {
      'en' => en,
      'ja' => switch (zh) {
        '回滚失败' => 'ロールバック失敗',
        '选择目录失败' => 'フォルダ選択失敗',
        '备份失败' => 'バックアップ失敗',
        '批量操作失败' => '一括操作失敗',
        '导出失败' => 'エクスポート失敗',
        '保存图片失败' => '画像保存失敗',
        '操作失败' => '操作失敗',
        'CSV 导出失败' => 'CSV出力失敗',
        '备份校验失败' => 'バックアップ検証失敗',
        '导入失败' => 'インポート失敗',
        '撤销失败' => '元に戻せません',
        _ => '追加失敗',
      },
      'fr' => switch (zh) {
        '回滚失败' => 'Échec de la restauration',
        '选择目录失败' => 'Sélection du dossier impossible',
        '备份失败' => 'Échec de la sauvegarde',
        '批量操作失败' => "Échec de l'action groupée",
        '导出失败' => "Échec de l'export",
        '保存图片失败' => "Échec de l'enregistrement de l'image",
        '操作失败' => "Échec de l'action",
        'CSV 导出失败' => "Échec de l'export CSV",
        '备份校验失败' => 'Échec de la validation',
        '导入失败' => "Échec de l'import",
        '撤销失败' => "Échec de l'annulation",
        _ => "Échec de l'ajout",
      },
      'es' => switch (zh) {
        '回滚失败' => 'Error al revertir',
        '选择目录失败' => 'No se pudo seleccionar la carpeta',
        '备份失败' => 'Error de copia de seguridad',
        '批量操作失败' => 'Error en la acción por lotes',
        '导出失败' => 'Error al exportar',
        '保存图片失败' => 'Error al guardar la imagen',
        '操作失败' => 'Error en la operación',
        'CSV 导出失败' => 'Error al exportar CSV',
        '备份校验失败' => 'Error de validación',
        '导入失败' => 'Error al importar',
        '撤销失败' => 'Error al deshacer',
        _ => 'Error al añadir',
      },
      _ => zh,
    };
  }

  static String? _pick(String en, String ja, String fr, String es) {
    return switch (languageCode) {
      'en' => en,
      'ja' => ja,
      'fr' => fr,
      'es' => es,
      _ => null,
    };
  }

  /// 处理带数字/任务名的动态文案。
  static String? _pattern(String zh) {
    final colonIndex = zh.indexOf('：');
    if (colonIndex > 0) {
      final localized = _errorPrefix(zh.substring(0, colonIndex));
      if (localized != null) {
        return '$localized: ${zh.substring(colonIndex + 1)}';
      }
    }
    final progress = RegExp(r'^已完成 (\d+) 项 · 还剩 (\d+) 项$').firstMatch(zh);
    if (progress != null) {
      final done = progress.group(1)!, left = progress.group(2)!;
      return _pick(
        'Completed $done · $left left',
        '完了 $done 件 · 残り $left 件',
        'Terminé $done · $left restants',
        'Completado $done · quedan $left',
      );
    }
    final checkinChip = RegExp(r'^打卡 (\d+)/(\d+)$').firstMatch(zh);
    if (checkinChip != null) {
      final done = checkinChip.group(1)!, total = checkinChip.group(2)!;
      return _pick(
        'Check-ins $done/$total',
        'チェック $done/$total',
        'Pointages $done/$total',
        'Registros $done/$total',
      );
    }
    final todoChip = RegExp(r'^(\d+) 项待办$').firstMatch(zh);
    if (todoChip != null) {
      final n = todoChip.group(1)!;
      return _pick('$n to-dos', '$n 件のToDo', '$n à faire', '$n pendientes');
    }
    // 今日页“临时待办”标题右侧的纯数量标签，例如“3 项”。
    final countChip = RegExp(r'^(\d+) 项$').firstMatch(zh);
    if (countChip != null) {
      final n = countChip.group(1)!;
      return _pick('$n items', '$n 件', '$n éléments', '$n elementos');
    }
    final due = RegExp(r'^(已逾期|截止) (.+)$').firstMatch(zh);
    if (due != null) {
      final label = due.group(1)!, date = due.group(2)!;
      return _pick(
        '${label == '已逾期' ? 'Overdue' : 'Due'} $date',
        '${label == '已逾期' ? '期限切れ' : '期限'} $date',
        '${label == '已逾期' ? 'En retard' : 'Échéance'} $date',
        '${label == '已逾期' ? 'Atrasado' : 'Vence'} $date',
      );
    }
    final reminder = RegExp(r'^提醒 (\d{2}:\d{2})$').firstMatch(zh);
    if (reminder != null) {
      final t = reminder.group(1)!;
      return _pick('Reminder $t', 'リマインダー $t', 'Rappel $t', 'Recordatorio $t');
    }
    final weekly = RegExp(r'^每周 (\d+) 次$').firstMatch(zh);
    if (weekly != null) {
      final n = weekly.group(1)!;
      return _pick(
        '$n× per week',
        '週$n回',
        '$n fois/semaine',
        '$n veces/semana',
      );
    }
    final interval = RegExp(r'^每 (\d+) 天$').firstMatch(zh);
    if (interval != null) {
      final n = interval.group(1)!;
      return _pick(
        'Every $n days',
        '$n日ごと',
        'Tous les $n jours',
        'Cada $n días',
      );
    }

    final unit = RegExp(r'^(\d+) (份|天|月|日)$').firstMatch(zh);
    if (unit != null) {
      final n = unit.group(1)!;
      final u = unit.group(2)!;
      final en = switch (u) {
        '份' => 'copies',
        '天' => 'days',
        '月' => 'months',
        _ => 'days',
      };
      return switch (languageCode) {
        'en' => '$n $en',
        'ja' => '$n$u',
        'fr' => '$n $en',
        'es' => '$n $en',
        _ => zh,
      };
    }

    final streak = RegExp(r'^(当前连续|最长连续|累计打卡) (\d+) 天$').firstMatch(zh);
    if (streak != null) {
      final n = streak.group(2)!;
      final label = switch ((languageCode, streak.group(1))) {
        ('en', '当前连续') => 'Current streak',
        ('en', '最长连续') => 'Longest streak',
        ('en', _) => 'Total check-ins',
        ('ja', '当前连续') => '現在の連続',
        ('ja', '最长连续') => '最長連続',
        ('ja', _) => '累計チェックイン',
        ('fr', '当前连续') => 'Série actuelle',
        ('fr', '最长连续') => 'Plus longue série',
        ('fr', _) => 'Total de check-ins',
        ('es', '当前连续') => 'Racha actual',
        ('es', '最长连续') => 'Racha más larga',
        ('es', _) => 'Check-ins totales',
        _ => '',
      };
      if (label.isNotEmpty) return '$label $n';
    }

    final archive = RegExp(r'^归档 (\d+) 个任务？$').firstMatch(zh);
    if (archive != null) {
      final n = archive.group(1)!;
      return switch (languageCode) {
        'en' => 'Archive $n tasks?',
        'ja' => '$n件のタスクをアーカイブしますか？',
        'fr' => 'Archiver $n tâches ?',
        'es' => '¿Archivar $n tareas?',
        _ => zh,
      };
    }

    final remove = RegExp(r'^永久删除 (\d+) 项？$').firstMatch(zh);
    if (remove != null) {
      final n = remove.group(1)!;
      return switch (languageCode) {
        'en' => 'Permanently delete $n items?',
        'ja' => '$n件を完全に削除しますか？',
        'fr' => 'Supprimer définitivement $n éléments ?',
        'es' => '¿Eliminar $n elementos permanentemente?',
        _ => zh,
      };
    }

    final month = RegExp(r'^(\d+)月$').firstMatch(zh);
    if (month != null) {
      final n = month.group(1)!;
      return switch (languageCode) {
        'en' => 'Month $n',
        'ja' => '$n月',
        'fr' => 'Mois $n',
        'es' => 'Mes $n',
        _ => zh,
      };
    }

    final quoted = RegExp(r'^「(.+)」会从今日列表移除，历史记录仍会保留，可在回收站恢复。$').firstMatch(zh);
    if (quoted != null) {
      final title = quoted.group(1)!;
      return switch (languageCode) {
        'en' =>
          '"$title" will leave Today; history is kept and can be restored from the recycle bin.',
        'ja' => '「$title」は今日の一覧から外れます。履歴は保持され、ゴミ箱から復元できます。',
        'fr' =>
          '"$title" quittera Aujourd\'hui ; l\'historique est conservé et restaurable depuis la corbeille.',
        'es' =>
          '«$title» saldrá de Hoy; el historial se conserva y puede restaurarse desde la papelera.',
        _ => zh,
      };
    }

    final colon = zh.indexOf('：');
    if (colon > 0) {
      final rawPrefix = zh.substring(0, colon);
      final prefix = tr(rawPrefix);
      if (prefix != rawPrefix) {
        return '$prefix: ${zh.substring(colon + 1)}';
      }
    }
    final imported = RegExp(r'^导入完成：任务 (\d+) · 打卡 (\d+) · 标签 (\d+)$')
        .firstMatch(zh);
    if (imported != null) {
      final t = imported[1]!, c = imported[2]!, g = imported[3]!;
      return _pick(
        'Import complete: $t tasks · $c check-ins · $g tags',
        'インポート完了: タスク $t · チェック $c · タグ $g',
        'Import terminé : $t tâches · $c pointages · $g tags',
        'Importación completa: $t tareas · $c registros · $g etiquetas',
      );
    }

    final compared = RegExp(r'^较上期 ([+-]?\d+)(%?)$').firstMatch(zh);
    if (compared != null) {
      final value = '${compared[1]}${compared[2]}';
      return _pick(
        'vs previous $value',
        '前期比 $value',
        'vs période précédente $value',
        'vs periodo anterior $value',
      );
    }

    final weekdayDone = RegExp(r'^(.+) · 完成 (\d+)/(\d+)$').firstMatch(zh);
    if (weekdayDone != null) {
      final w = weekdayDone[1]!, a = weekdayDone[2]!, b = weekdayDone[3]!;
      return _pick(
        '$w · $a/$b done',
        '$w · $a/$b 完了',
        '$w · $a/$b terminés',
        '$w · $a/$b completados',
      );
    }

    final weekdayMotto = RegExp(r'^(.+) · 把今天过好$').firstMatch(zh);
    if (weekdayMotto != null) {
      return _pick(
        '${weekdayMotto[1]} · Make today count',
        '${weekdayMotto[1]} · 今日を大切に',
        '${weekdayMotto[1]} · Profite de la journée',
        '${weekdayMotto[1]} · Aprovecha el día',
      );
    }

    final dayAverage = RegExp(r'^(\d+) 天 · 均 (\d+)%$').firstMatch(zh);
    if (dayAverage != null) {
      final d = dayAverage[1]!, p = dayAverage[2]!;
      return _pick(
        '$d days · avg $p%',
        '$d 日 · 平均 $p%',
        '$d jours · moy. $p %',
        '$d días · prom. $p %',
      );
    }

    final backup = RegExp(r'^已备份 (.+)$').firstMatch(zh);
    if (backup != null) {
      return _pick(
        'Backup saved: ${backup[1]}',
        '保存しました: ${backup[1]}',
        'Sauvegarde : ${backup[1]}',
        'Copia guardada: ${backup[1]}',
      );
    }

    final perfect = RegExp(r'^连续全勤 (\d+) 天$').firstMatch(zh);
    if (perfect != null) {
      final n = perfect[1]!;
      return _pick(
        'Perfect streak: $n days',
        '連続全勤 $n 日',
        'Série parfaite : $n jours',
        'Racha perfecta: $n días',
      );
    }

    final week = RegExp(r'^本周 (\d+)/(\d+) 次$').firstMatch(zh);
    if (week != null) {
      final a = week[1]!, b = week[2]!;
      return _pick(
        'This week: $a/$b',
        '今週 $a/$b 回',
        'Cette semaine : $a/$b',
        'Esta semana: $a/$b',
      );
    }

    final todayDone = RegExp(r'^今日打卡\s+(\d+)/(\d+)$').firstMatch(zh);
    if (todayDone != null) {
      final a = todayDone[1]!, b = todayDone[2]!;
      return _pick(
        'Today: $a/$b',
        '今日のチェックイン: $a/$b',
        "Aujourd'hui : $a/$b",
        'Hoy: $a/$b',
      );
    }

    final itemsDone = RegExp(r'^(\d+)/(\d+) 项完成$').firstMatch(zh);
    if (itemsDone != null) {
      final a = itemsDone[1]!, b = itemsDone[2]!;
      return _pick(
        '$a/$b done',
        '$a/$b 完了',
        '$a/$b terminés',
        '$a/$b completados',
      );
    }

    final items = RegExp(r'^(\d+)/(\d+) 项$').firstMatch(zh);
    if (items != null) {
      final a = items[1]!, b = items[2]!;
      return _pick(
        '$a/$b items',
        '$a/$b 件',
        '$a/$b éléments',
        '$a/$b elementos',
      );
    }

    final countItems = RegExp(r'^(\d+) 项$').firstMatch(zh);
    if (countItems != null) {
      final n = countItems[1]!;
      return _pick('$n items', '$n 件', '$n éléments', '$n elementos');
    }

    final avg8 = RegExp(r'^近 8 周平均 (\d+)%$').firstMatch(zh);
    if (avg8 != null) {
      final n = avg8[1]!;
      return _pick(
        '8-week average: $n%',
        '直近8週平均: $n%',
        'Moyenne 8 semaines : $n %',
        'Promedio 8 semanas: $n %',
      );
    }

    final doneRate = RegExp(r'^完成 (\d+)/(\d+) · (\d+)%$').firstMatch(zh);
    if (doneRate != null) {
      final a = doneRate[1]!, b = doneRate[2]!, p = doneRate[3]!;
      return _pick(
        '$a/$b · $p%',
        '$a/$b · $p%',
        '$a/$b · $p %',
        '$a/$b · $p %',
      );
    }

    final note = RegExp(r'^备注[：:]\s*(.+)$').firstMatch(zh);
    if (note != null) {
      return _pick(
        'Note: ${note[1]}',
        'メモ: ${note[1]}',
        'Note : ${note[1]}',
        'Nota: ${note[1]}',
      );
    }

    final upcoming = RegExp(r'^近期生效[：:]\s*(.+)$').firstMatch(zh);
    if (upcoming != null) {
      return _pick(
        'Upcoming: ${upcoming[1]}',
        '次回の適用日: ${upcoming[1]}',
        'Prochaines dates : ${upcoming[1]}',
        'Próximas fechas: ${upcoming[1]}',
      );
    }

    final completedAt = RegExp(r'^完成于 (.+)$').firstMatch(zh);
    if (completedAt != null) {
      return _pick(
        'Completed at ${completedAt[1]}',
        '完了日時: ${completedAt[1]}',
        'Terminé à ${completedAt[1]}',
        'Completado el ${completedAt[1]}',
      );
    }

    final totalAvg = RegExp(r'^累计 (\d+) 天 · 均 (\d+)%$').firstMatch(zh);
    if (totalAvg != null) {
      final n = totalAvg[1]!, p = totalAvg[2]!;
      return _pick(
        'Total $n days · avg $p%',
        '累計 $n 日 · 平均 $p%',
        'Total $n jours · moy. $p %',
        'Total $n días · prom. $p %',
      );
    }

    final found = RegExp(r'^发现 (\d+) 条可修复的数据问题').firstMatch(zh);
    if (found != null) {
      final n = found[1]!;
      return _pick(
        'Found $n repairable issues',
        '修復可能な問題が $n 件あります',
        '$n problèmes réparables détectés',
        'Se encontraron $n problemas reparables',
      );
    }

    final backupDate = RegExp(r'^备份日期[：:]\s*(.*)$').firstMatch(zh);
    if (backupDate != null) {
      return _pick(
        'Backup date: ${backupDate[1]}',
        'バックアップ日: ${backupDate[1]}',
        'Date de sauvegarde : ${backupDate[1]}',
        'Fecha de copia: ${backupDate[1]}',
      );
    }

    if (zh == '中文原文') {
      return _pick(
        'Chinese original',
        '中国語原文',
        'Original chinois',
        'Original chino',
      );
    }

    return null;
  }
}
