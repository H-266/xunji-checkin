// Promo export kit: renders the REAL 循记打卡 screens at 1080x2400@3x and
// writes PNGs for the Remotion promo film. No fake providers, no redrawing:
// real SQLite (ffi) + real TaskProvider + real screens.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:xunji_checkin/core/app_strings.dart';
import 'package:xunji_checkin/data/app_database.dart';
import 'package:xunji_checkin/l10n/app_localizations.dart';
import 'package:xunji_checkin/providers/settings_provider.dart';
import 'package:xunji_checkin/providers/task_provider.dart';
import 'package:xunji_checkin/screens/heatmap_screen.dart';
import 'package:xunji_checkin/screens/settings_screen.dart';
import 'package:xunji_checkin/screens/today_screen.dart';
import 'package:xunji_checkin/screens/widget_config_screen.dart';
import 'package:xunji_checkin/theme/app_theme.dart';

// A modern 393x873pt phone (iPhone 15 / Pixel class). The film's 1080x2400
// canvas is 393x873 * 2.748, so pages are exported at 3x and scaled 0.916.
const double kLogicalW = 393;
const double kLogicalH = 873;
const double kDpr = 3;
const double kPadTop = 30;
const double kPadBottom = 26;

/// Repo root as seen from stage12/test (flutter test cwd == stage12).
final String promoRoot =
    Directory.current.path.replaceAll('\\', '/') + '/../docs/promo-video';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getApplicationCachePath() async => dir;
}

Future<void> loadPromoFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  // Material icon glyphs (otherwise every Icon renders as tofu in tests).
  await family('MaterialIcons', [
    r'D:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
  ]);

  const win = r'C:\Windows\Fonts';
  final fonts = promoRoot + '/assets/fonts';
  final noto = [
    fonts + '/NotoSansSC_400Regular.ttf',
    fonts + '/NotoSansSC_500Medium.ttf',
    fonts + '/NotoSansSC_600SemiBold.ttf',
    fonts + '/NotoSansSC_700Bold.ttf',
    fonts + '/NotoSansSC_900Black.ttf',
  ];
  // Our own theme asks for 'PromoSans' (the real Roboto faces) with NotoSC as
  // the CJK fallback, exactly like a phone.
  await family('PromoSans', [
    win + r'\Roboto-Regular.ttf',
    win + r'\Roboto-Medium.ttf',
    win + r'\Roboto-Bold.ttf',
    win + r'\Roboto-Black.ttf',
  ]);
  await family('NotoSC', noto);
  // Some routes (the global search page) rebuild their ThemeData inside the
  // app, so they carry no fontFamilyFallback and fall back to Typography's
  // default family. Registering the CJK faces under 'Roboto' gives those
  // routes a default family that already covers Chinese instead of Ahem.
  await family('Roboto', noto);
}

// ---------------------------------------------------------------------------
// Demo data (deterministic: fixed seed, dates relative to "today")
// ---------------------------------------------------------------------------

class DemoData {
  static const List<String> tagNames = ['学习', '健身', '阅读', '生活'];
  static const List<int> tagColors = [
    0xFF5B7CFA,
    0xFF35C48A,
    0xFFE0A33E,
    0xFF8E7CF0,
  ];
}

Future<Directory> bootDb() async {
  final tmp = Directory.systemTemp.createTempSync('xunji_promo_');
  PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  return tmp;
}

String key(DateTime d) =>
    d.year.toString().padLeft(4, '0') +
    '-' +
    d.month.toString().padLeft(2, '0') +
    '-' +
    d.day.toString().padLeft(2, '0');

/// Seeds ~200 days of history so the heatmaps have real texture.
Future<void> seedDemo() async {
  final db = await AppDatabase.instance.database;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final createdAt =
      today.subtract(const Duration(days: 208)).add(const Duration(hours: 9));

  final tagIds = <String, int>{};
  for (var i = 0; i < DemoData.tagNames.length; i++) {
    tagIds[DemoData.tagNames[i]] = await db.insert('tags', {
      'name': DemoData.tagNames[i],
      'color': DemoData.tagColors[i],
      'created_at': createdAt.millisecondsSinceEpoch,
    });
  }

  Future<int> task(
    String title, {
    required String tag,
    int sort = 0,
    String type = 'daily',
    String schedule = 'daily',
    int? completedAt,
    int? archivedAt,
  }) {
    return db.insert('tasks', {
      'title': title,
      'type': type,
      'created_at': createdAt.millisecondsSinceEpoch,
      'completed_at': completedAt,
      'archived_at': archivedAt,
      'sort_order': sort,
      'schedule_type': schedule,
      'weekly_target': 7,
      'weekday_mask': 127,
      'tag_id': tagIds[tag],
      'reminder_enabled': 0,
      'reminder_effective_only': 0,
      'interval_days': 1,
      'month_days_mask': 1,
    });
  }

  final dailies = <int>[
    await task('晨跑 5 公里', tag: '健身', sort: 0),
    await task('读书 30 分钟', tag: '阅读', sort: 1),
    await task('背 50 个单词', tag: '学习', sort: 2),
    await task('冥想 10 分钟', tag: '生活', sort: 3),
    await task('拉伸 15 分钟', tag: '健身', sort: 4),
  ];
  final retired = await task(
    '早睡打卡 23:00',
    tag: '生活',
    sort: 9,
    archivedAt: today.subtract(const Duration(days: 62)).millisecondsSinceEpoch,
  );

  final rand = Random(42);

  // ~200 days of history. Each day picks a target completion *rate* (so the
  // heatmap reads like a real habit: zeros, half days, perfect weeks), then
  // forces exactly that many of the day's tasks to be done.
  final rows = <List<Object?>>[];
  const span = 200;
  for (var i = span; i >= 0; i--) {
    final d = today.subtract(Duration(days: i));
    final k = key(d);
    final weekday = d.weekday;
    double target;
    if (i == 0) {
      target = 0.2; // two of ten -> a light start for the film's first beat
    } else if (i <= 3) {
      target = 0.4; // a small slump right before "today", keeps the ring honest
    } else {
      final r = rand.nextDouble();
      target = r < 0.10
          ? 0.0
          : r < 0.30
          ? 0.2
          : r < 0.55
          ? 0.4
          : r < 0.78
          ? 0.6
          : r < 0.92
          ? 0.8
          : 1.0;
      if (weekday >= 6) target -= 0.2; // weekends dip
      if (target < 0) target = 0;
    }
    final done = (target * dailies.length).round();
    final ids = [...dailies]..shuffle(rand);
    for (var n = 0; n < done; n++) {
      rows.add([
        ids[n],
        k,
        d.add(Duration(hours: 7 + n)).millisecondsSinceEpoch,
        null,
      ]);
    }
    if (i > 62 && rand.nextDouble() < 0.5) {
      rows.add([
        retired,
        k,
        d.add(const Duration(hours: 23)).millisecondsSinceEpoch,
        null,
      ]);
    }
  }
  rows.removeWhere((r) => r[1] == key(today));
  // Today: exactly one of the five daily tasks is done (25%).
  rows.add([
    dailies[0],
    key(today),
    today.add(const Duration(hours: 7, minutes: 12)).millisecondsSinceEpoch,
    null,
  ]);

  final batch = db.batch();
  for (final r in rows) {
    batch.insert('checkins', {
      'task_id': r[0],
      'date': r[1],
      'completed_ts': r[2],
      'remark': r[3],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
}

// ---------------------------------------------------------------------------
// App under test
// ---------------------------------------------------------------------------

class PromoShell extends StatelessWidget {
  const PromoShell({super.key, required this.tab});
  final int tab;


  Widget _page() => switch (tab) {
    1 => const HeatmapScreen(),
    2 => const WidgetConfigScreen(),
    3 => const SettingsScreen(),
    _ => const TodayScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(index: tab, children: [
        for (var i = 0; i < 4; i++) i == tab ? _page() : const SizedBox.shrink(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (_) {},
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today_rounded),
            label: l10n.tabToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: l10n.tabHeatmap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.widgets_outlined),
            selectedIcon: const Icon(Icons.widgets_rounded),
            label: l10n.tabWidgets,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune_rounded),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}

/// Same chrome as [PromoShell] but the bottom bar actually switches tabs, so
/// a capture can show a real tab change (used by the feature demo clips).
class PromoLiveShell extends StatefulWidget {
  const PromoLiveShell({super.key});

  @override
  State<PromoLiveShell> createState() => _PromoLiveShellState();
}

class _PromoLiveShellState extends State<PromoLiveShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          TodayScreen(),
          HeatmapScreen(),
          WidgetConfigScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today_rounded),
            label: l10n.tabToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: l10n.tabHeatmap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.widgets_outlined),
            selectedIcon: const Icon(Icons.widgets_rounded),
            label: l10n.tabWidgets,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune_rounded),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}

/// Bottom nav strip used when a page is rendered standalone (stats / year
/// heatmap are pushed routes in the real app, but keep the same chrome).
class _NavBarStandIn extends StatelessWidget {
  const _NavBarStandIn();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NavigationBar(
      selectedIndex: 1,
      onDestinationSelected: (_) {},
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.today_outlined),
          label: l10n.tabToday,
        ),
        NavigationDestination(
          icon: const Icon(Icons.grid_view_rounded),
          label: l10n.tabHeatmap,
        ),
        NavigationDestination(
          icon: const Icon(Icons.widgets_outlined),
          label: l10n.tabWidgets,
        ),
        NavigationDestination(
          icon: const Icon(Icons.tune_outlined),
          label: l10n.tabSettings,
        ),
      ],
    );
  }
}

ThemeData promoTheme(ThemeData base) {
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'PromoSans',
      fontFamilyFallback: const ['NotoSC'],
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamily: 'PromoSans',
      fontFamilyFallback: const ['NotoSC'],
    ),
    // AppBarTheme captured a fully-resolved titleLarge before the apply above,
    // so patch it too or the title renders as tofu boxes in tests.
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'PromoSans',
        fontFamilyFallback: const ['NotoSC'],
      ),
    ),
  );
}

class PromoApp extends StatelessWidget {
  const PromoApp({
    super.key,
    required this.tab,
    this.brightness = Brightness.dark,
    this.hue = 220,
    this.page,
    this.live = false,
  });
  final int tab;
  final Brightness brightness;
  final double hue;
  final Widget? page;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = promoTheme(AppTheme.build(hue: hue, brightness: brightness));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme,
      darkTheme: theme,
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) {
        final resolved = Localizations.localeOf(context);
        AppStrings.languageCode = resolved.languageCode;
        final media = MediaQuery.of(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        final surface = Theme.of(context).scaffoldBackgroundColor;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: surface,
            systemNavigationBarColor: surface,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          ),
          child: MediaQuery(
            data: media.copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: live
          ? const PromoLiveShell()
          : page == null
          ? PromoShell(tab: tab)
          : Scaffold(
              body: page,
              bottomNavigationBar: const _NavBarStandIn(),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Capture helpers
// ---------------------------------------------------------------------------

Future<void> prepDevice(
  WidgetTester tester, {
  double? height,
  double width = kLogicalW,
}) async {
  final h = height ?? kLogicalH;
  tester.view.devicePixelRatio = kDpr;
  tester.view.physicalSize = Size(width * kDpr, h * kDpr);
  tester.view.padding = FakeViewPadding(
    top: kPadTop * kDpr,
    bottom: kPadBottom * kDpr,
  );
  tester.view.viewPadding = FakeViewPadding(top: kPadTop * kDpr);
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

final GlobalKey kRootKey = GlobalKey();

Future<void> pumpApp(
  WidgetTester tester,
  Widget app, {
  double height = kLogicalH,
  double width = kLogicalW,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: kRootKey,
      child: SizedBox(width: width, height: height, child: app),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> shoot(
  WidgetTester tester,
  String relativePath, {
  double pixelRatio = kDpr,
}) async {
  final boundary =
      kRootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(promoRoot + '/' + relativePath)
      ..createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
    // ignore: avoid_print
    print('saved ' + file.path + ' ' + file.lengthSync().toString() + 'B');
  });
}

Future<List<Object>> bootProviders() async {
  final tasks = TaskProvider();
  await tasks.load();
  final settings = SettingsProvider();
  await settings.load();
  return [tasks, settings];
}

Widget wrapProviders(
  Widget child,
  TaskProvider tasks,
  SettingsProvider settings,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TaskProvider>.value(value: tasks),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
    ],
    child: child,
  );
}