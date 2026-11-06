import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xunji_checkin/models/task.dart';
import 'package:xunji_checkin/theme/app_theme.dart';
import 'package:xunji_checkin/widgets/progress_ring.dart';
import 'package:xunji_checkin/widgets/task_tile.dart';

void main() {
  testWidgets('完成态任务显示删除线，点勾选框触发回调', (tester) async {
    var toggleCount = 0;
    final task = Task(
      id: 1,
      title: '喝水',
      type: TaskType.daily,
      createdAt: DateTime(2026, 11, 1).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskTile(
            task: task,
            done: true,
            onToggle: () => toggleCount++,
            onEdit: () {},
          ),
        ),
      ),
    );

    final styles = tester
        .widgetList<AnimatedDefaultTextStyle>(
          find.descendant(
            of: find.byType(TaskTile),
            matching: find.byType(AnimatedDefaultTextStyle),
          ),
        )
        .map((widget) => widget.style.decoration);
    expect(styles, contains(TextDecoration.lineThrough));

    await tester.tap(find.byKey(const ValueKey<String>('check-1')));
    await tester.pump();
    expect(toggleCount, 1);
  });

  testWidgets('进度环展示百分比和自定义中心内容', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProgressRing(
            value: 0.5,
            color: Colors.green,
            center: const Text('一半'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('一半'), findsOneWidget);
    expect(find.text('50%'), findsNothing);
  });

  test('100% 热度色是拉满的高亮色', () {
    final color = AppTheme.heatColor(hue: 152, rate: 1, isDark: false);
    final expected = HSVColor.fromAHSV(1, 152, 1, 1).toColor();
    expect(color, expected);
  });

  test('0% 与无任务使用安静底色', () {
    final zero = AppTheme.heatColor(
      hue: 152,
      rate: 0,
      isDark: false,
      hasTasks: true,
    );
    final noTask = AppTheme.heatColor(
      hue: 152,
      rate: 1,
      isDark: false,
      hasTasks: false,
    );
    expect(zero, AppTheme.lightHeatBase);
    expect(noTask, AppTheme.lightHeatBase);
  });
}
