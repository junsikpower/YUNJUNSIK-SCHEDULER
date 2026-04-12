import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'schedule_parser.dart';

/// 앱 전역에서 알림바(팝업)를 띄우기 위한 키
final GlobalKey<ScaffoldMessengerState> globalMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class NotificationRuntimeReport {
  final DateTime updatedAt;
  final bool? androidNotificationPermission;
  final bool? androidExactAlarmAllowed;
  final int requestedCount;
  final int successCount;
  final int failedCount;
  final int pendingCount;
  final List<String> logs;

  const NotificationRuntimeReport({
    required this.updatedAt,
    required this.androidNotificationPermission,
    required this.androidExactAlarmAllowed,
    required this.requestedCount,
    required this.successCount,
    required this.failedCount,
    required this.pendingCount,
    required this.logs,
  });

  factory NotificationRuntimeReport.initial() {
    return NotificationRuntimeReport(
      updatedAt: DateTime.now(),
      androidNotificationPermission: null,
      androidExactAlarmAllowed: null,
      requestedCount: 0,
      successCount: 0,
      failedCount: 0,
      pendingCount: 0,
      logs: const [],
    );
  }
}

class NotificationService {
  static const int legacyTestAlarmId = 900001;
  static const String _channelId = 'tta_alarm_channel';
  static const String _channelName = 'TTA 알림';
  static const String _channelDescription = '일정 시작/종료 및 데일리 브리핑 알림';

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 앱이 켜져 있을 때 (노트북 등) 정확한 타이머로 알림을 띄워주는 리스트
  static final Map<int, Timer> _activeTimers = {};

  static final ValueNotifier<NotificationRuntimeReport> diagnosticsNotifier =
      ValueNotifier<NotificationRuntimeReport>(NotificationRuntimeReport.initial());

  static final List<String> _diagnosticLogs = [];
  static bool? _androidNotificationPermission;
  static bool? _androidExactAlarmAllowed;
  static int _requestedCount = 0;
  static int _successCount = 0;
  static int _failedCount = 0;
  static int _pendingCount = 0;

  static void _log(String message) {
    final line =
        '[${DateTime.now().toIso8601String()}] NotificationService: $message';
    debugPrint(line);
    _diagnosticLogs.add(line);
    if (_diagnosticLogs.length > 120) {
      _diagnosticLogs.removeRange(0, _diagnosticLogs.length - 120);
    }
  }

  static void _publishDiagnostics() {
    diagnosticsNotifier.value = NotificationRuntimeReport(
      updatedAt: DateTime.now(),
      androidNotificationPermission: _androidNotificationPermission,
      androidExactAlarmAllowed: _androidExactAlarmAllowed,
      requestedCount: _requestedCount,
      successCount: _successCount,
      failedCount: _failedCount,
      pendingCount: _pendingCount,
      logs: List<String>.from(_diagnosticLogs),
    );
  }

  static Future<void> refreshDiagnostics() async {
    if (!Platform.isAndroid) {
      _publishDiagnostics();
      return;
    }

    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    _androidNotificationPermission =
        await androidPlugin?.areNotificationsEnabled();
    _androidExactAlarmAllowed =
        await androidPlugin?.canScheduleExactNotifications();

    try {
      _pendingCount =
          (await _localNotificationsPlugin.pendingNotificationRequests()).length;
    } catch (e) {
      _log('pendingNotificationRequests 조회 실패: $e');
    }
    _publishDiagnostics();
  }

  static Future<void> initialize() async {
    // 타임존 초기화 (스케줄링에 필수)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    // OS별 알림 설정
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    try {
      await _localNotificationsPlugin.initialize(initSettings);
      _log('플러그인 initialize 완료');

      // 안드로이드 13 버전 이상의 경우 권한 요청
      if (Platform.isAndroid) {
        final androidPlugin = _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          _log('안드로이드 알림 채널 생성/확인 완료');
        }

        _androidNotificationPermission =
            await androidPlugin?.areNotificationsEnabled();
        _log('초기 알림 권한 상태: $_androidNotificationPermission');

        final notifRequestResult =
            await androidPlugin?.requestNotificationsPermission();
        _log('알림 권한 요청 결과: $notifRequestResult');

        _androidNotificationPermission =
            await androidPlugin?.areNotificationsEnabled();
        _log('요청 후 알림 권한 상태: $_androidNotificationPermission');

        _androidExactAlarmAllowed =
            await androidPlugin?.canScheduleExactNotifications();
        _log('초기 Exact Alarm 허용 상태: $_androidExactAlarmAllowed');

        final exactRequestResult =
            await androidPlugin?.requestExactAlarmsPermission();
        _log('Exact Alarm 권한 요청 결과: $exactRequestResult');

        _androidExactAlarmAllowed =
            await androidPlugin?.canScheduleExactNotifications();
        _log('요청 후 Exact Alarm 허용 상태: $_androidExactAlarmAllowed');
      }
    } catch (e) {
      _log('initialize 실패: $e');
    }

    await clearLegacyTestAlarm();
    await refreshDiagnostics();

    // 윈도우 전용 알람 부품 초기화
    if (Platform.isWindows) {
      try {
        await localNotifier.setup(appName: '윤준식 스케줄러', shortcutPolicy: ShortcutPolicy.requireCreate);
        _log('Windows local_notifier setup 완료');
      } catch (e) {
        _log('Windows local_notifier setup 실패: $e');
      }
    }
  }

  /// 앱 UI가 올라온 직후 호출하여 권한 팝업이 확실히 뜨도록 보강
  static Future<void> requestPermissionsOnAppStart() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    try {
      final enabledBefore = await androidPlugin.areNotificationsEnabled();
      _log('앱 시작 후 권한 재확인(요청 전): $enabledBefore');

      if (enabledBefore != true) {
        final notifRequestResult =
            await androidPlugin.requestNotificationsPermission();
        _log('앱 시작 후 알림 권한 요청 결과: $notifRequestResult');
      }

      final exactAllowedBefore =
          await androidPlugin.canScheduleExactNotifications();
      _log('앱 시작 후 Exact Alarm 상태(요청 전): $exactAllowedBefore');
      if (exactAllowedBefore != true) {
        final exactRequestResult =
            await androidPlugin.requestExactAlarmsPermission();
        _log('앱 시작 후 Exact Alarm 권한 요청 결과: $exactRequestResult');
      }

      _androidNotificationPermission =
          await androidPlugin.areNotificationsEnabled();
      _androidExactAlarmAllowed =
          await androidPlugin.canScheduleExactNotifications();
    } catch (e) {
      _log('앱 시작 후 권한 요청 실패: $e');
    }

    await refreshDiagnostics();
  }

  /// 새로운 파싱 데이터가 들어오면 모든 알림을 재설정
  static Future<void> scheduleAlarms(List<DayPlan> dayPlans) async {
    _requestedCount = 0;
    _successCount = 0;
    _failedCount = 0;

    // 1. 기존 잔여 알람 모두 취소
    try {
      await _localNotificationsPlugin.cancelAll();
      _log('기존 시스템 알림 전체 취소 완료');
    } catch (_) {
      // 윈도우 등 플러그인 미지원 플랫폼의 에러를 조용히 넘깁니다.
      _log('cancelAll 실패(지원 플랫폼/상태 확인 필요)');
    }
    for (var timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();

    await clearLegacyTestAlarm();

    final today = DateTime.now();
    final activePlan = ScheduleParser.pickActivePlan(dayPlans, now: today);
    if (activePlan == null) {
      await refreshDiagnostics();
      return;
    }

    final baseDate = ScheduleParser.resolvePlanDate(activePlan.dateLabel, today);
    int notificationId = 0;

    // 💡 활성 섹션의 첫 일정 시작 30분 전 다이제스트
    DateTime? firstStart;
    for (final block in activePlan.blocks) {
      if (block.startTime == null) continue;
      final candidate = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        block.startTime!.hour,
        block.startTime!.minute,
      );
      if (firstStart == null || candidate.isBefore(firstStart)) {
        firstStart = candidate;
      }
    }

    final digestTime = firstStart?.subtract(const Duration(minutes: 30));
    if (digestTime != null && digestTime.isAfter(today)) {
      final digestBody = _buildDigestBody(activePlan);
      final ok = await _scheduleExactTime(
        id: notificationId++,
        time: digestTime,
        title: '💕 오늘 하루 브리핑',
        body: digestBody,
      );
      _requestedCount++;
      if (ok) {
        _successCount++;
      } else {
        _failedCount++;
      }
    }

    // 💡 개별 알림 등록
    for (var block in activePlan.blocks) {
      if (block.startTime != null) {
        final sTime = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          block.startTime!.hour,
          block.startTime!.minute,
        );
        if (sTime.isAfter(today)) {
          final ok = await _scheduleExactTime(
            id: notificationId++,
            time: sTime,
            title: '🔔 알림',
            body: block.rawText.split('\n').first.trim(),
          );
          _requestedCount++;
          if (ok) {
            _successCount++;
          } else {
            _failedCount++;
          }
        }
      }

      if (block.endTime != null) {
        DateTime? eTime;
        if (block.isOvernight) {
          eTime = ScheduleParser.getOvernightEndTime(block, baseDate);
        } else {
          eTime = DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            block.endTime!.hour,
            block.endTime!.minute,
          );
        }

        if (eTime != null && eTime.isAfter(today)) {
          final ok = await _scheduleExactTime(
            id: notificationId++,
            time: eTime,
            title: '🔔 종료 알림',
            body: '${block.rawText.split('\n').first.trim()} 시간 종료됨',
          );
          _requestedCount++;
          if (ok) {
            _successCount++;
          } else {
            _failedCount++;
          }
        }
      }
    }

    await refreshDiagnostics();
    _log('알림 예약 요청 완료: requested=$_requestedCount, success=$_successCount, failed=$_failedCount, pending=$_pendingCount');
    _publishDiagnostics();
  }

  static Future<void> clearLegacyTestAlarm() async {
    try {
      await _localNotificationsPlugin.cancel(legacyTestAlarmId);
      _log('레거시 테스트 알림 취소 완료(id=$legacyTestAlarmId)');
    } catch (e) {
      _log('레거시 테스트 알림 취소 실패(id=$legacyTestAlarmId): $e');
    }

    final timer = _activeTimers.remove(legacyTestAlarmId);
    timer?.cancel();
  }

  static Future<void> cancelAlarmById(int id) async {
    try {
      await _localNotificationsPlugin.cancel(id);
      _log('개별 알림 취소 완료(id=$id)');
    } catch (e) {
      _log('개별 알림 취소 실패(id=$id): $e');
    }

    final timer = _activeTimers.remove(id);
    timer?.cancel();

    await refreshDiagnostics();
    _publishDiagnostics();
  }

  static String _buildDigestBody(DayPlan plan) {
    final lines = <String>[];

    for (final block in plan.blocks) {
      final raw = block.rawText.trim();
      if (raw.isNotEmpty) {
        lines.add(raw);
      }
    }

    if (plan.memos.isNotEmpty) {
      lines.add('[메모]');
      for (final memo in plan.memos) {
        final normalized = memo.trim();
        if (normalized.isNotEmpty) {
          lines.add(normalized);
        }
      }
    }

    if (lines.isEmpty) {
      return '오늘 등록된 일정이 없습니다.';
    }

    const maxLength = 450;
    final full = lines.join('\n');
    if (full.length <= maxLength) {
      return full;
    }
    return '${full.substring(0, maxLength)}\n...(이하 생략)';
  }

  /// 실제 시스템 알림 등록 + 인앱 타이머 등록
  static Future<bool> _scheduleExactTime({
    required int id,
    required DateTime time,
    required String title,
    required String body,
  }) async {
    bool scheduledToSystem = false;

    // 1. 모바일 기기용 (안드로이드/iOS) 백그라운드 OS 시스템 알람 등록
    if (!Platform.isWindows) {
      try {
        if (Platform.isAndroid) {
          final exactAllowed = _androidExactAlarmAllowed ?? false;

          if (exactAllowed) {
            await _scheduleWithMode(
              id: id,
              time: time,
              title: title,
              body: body,
              mode: AndroidScheduleMode.exactAllowWhileIdle,
            );
            scheduledToSystem = true;
            _log('[$id] exactAllowWhileIdle 예약 성공 @ $time');
          } else {
            await _scheduleWithMode(
              id: id,
              time: time,
              title: title,
              body: body,
              mode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
            scheduledToSystem = true;
            _log('[$id] Exact 거부 상태 -> inexactAllowWhileIdle 예약 성공 @ $time');
          }
        } else {
          await _scheduleWithMode(
            id: id,
            time: time,
            title: title,
            body: body,
            mode: AndroidScheduleMode.exactAllowWhileIdle,
          );
          scheduledToSystem = true;
        }
      } catch (e) {
        _log('[$id] 1차 예약 실패: $e');
        if (Platform.isAndroid) {
          try {
            await _scheduleWithMode(
              id: id,
              time: time,
              title: title,
              body: body,
              mode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
            scheduledToSystem = true;
            _log('[$id] fallback inexactAllowWhileIdle 예약 성공 @ $time');
          } catch (fallbackError) {
            _log('[$id] fallback 예약도 실패: $fallbackError');
            try {
              await _scheduleWithMode(
                id: id,
                time: time,
                title: title,
                body: body,
                mode: AndroidScheduleMode.inexactAllowWhileIdle,
              );
              scheduledToSystem = true;
              _log('[$id] fallback 2차 재시도 예약 성공 @ $time');
            } catch (retryError) {
              _log('[$id] fallback 2차 재시도도 실패: $retryError');
            }
          }
        }
      }
    }

    // 2. 포그라운드(앱 켜놓고 있을 때) 및 윈도우용 타이머 등록
    final delay = time.difference(DateTime.now());
    if (delay.isNegative) return scheduledToSystem;

    _activeTimers[id]?.cancel();
    final timer = Timer(delay, () {
      // 인앱 팝업 (스낵바) 띄우기
      _showInAppPopup(title, body);

      // 윈도우일 경우 윈도우 기본 알림(Toast) 도 같이 띄우기
      if (Platform.isWindows) {
        try {
          LocalNotification notification = LocalNotification(
            title: title,
            body: body,
          );
          notification.show();
        } catch (_) {}
      }
    });
    _activeTimers[id] = timer;
    return scheduledToSystem;
  }

  static Future<void> _scheduleWithMode({
    required int id,
    required DateTime time,
    required String title,
    required String body,
    required AndroidScheduleMode mode,
  }) async {
    await _localNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(time, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 노트북 등에서 앱을 열어두고 있을 때 즉시 알려주는 시각적 팝업
  static void _showInAppPopup(String title, String body) {
    if (globalMessengerKey.currentState == null) return;

    globalMessengerKey.currentState!.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFFFF6B81), // AppColors.primaryPink
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}
