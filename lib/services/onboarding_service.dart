import 'package:flutter/foundation.dart';

/// 教程重播信号。
///
/// 设置页不能直接操作 AppShell 的私有状态，用一个小型 ValueNotifier 解耦。
class OnboardingService {
  OnboardingService._();

  static final OnboardingService instance = OnboardingService._();

  final ValueNotifier<bool> replayRequested = ValueNotifier<bool>(false);

  void requestReplay() {
    replayRequested.value = !replayRequested.value;
  }
}
