import 'package:flutter/material.dart';

import '../core/app_strings.dart';

/// 与 [Text] 参数兼容的本地化文本。
///
/// 用 `LText('中文原文')` 替代 `Text('中文原文')`，文案表里存在对应翻译
/// 时按当前语言显示；构造仍可为 `const`，不会破坏现有组件树。
class LText extends StatelessWidget {
  const LText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;

  @override
  Widget build(BuildContext context) {
    // 订阅 Localizations：const LText 实例在语言切换时原本不会重建，
    // 这里建立依赖后，locale 一变所有 LText 都会重新 build。
    final code = AppStrings.codeForLocale(Localizations.localeOf(context));
    if (AppStrings.languageCode != code) {
      AppStrings.languageCode = code;
    }
    return Text(
      AppStrings.tr(data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
    );
  }
}
