/// 스케줄 파싱 엔진
/// - 사용자가 쓴 줄글에서 시간, 날짜, 메모를 자동으로 뽑아내는 두뇌 역할
/// - 오버나이트 로직: 23시 이후 01시처럼 날짜를 넘기는 일정을 올바르게 처리

/// ─── 시간 정보를 담는 데이터 구조 ───────────────────────────────
class ParsedTime {
  final int hour;   // 시 (0~23)
  final int minute; // 분 (0~59)

  const ParsedTime({required this.hour, required this.minute});

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// ─── 하나의 '할 일 덩어리' 데이터 구조 ────────────────────────────
class ScheduleBlock {
  final ParsedTime? startTime;  // 시작 시간 (없을 수도 있음)
  final ParsedTime? endTime;    // 종료 시간 (없을 수도 있음)
  final String rawText;         // 원본 줄 텍스트
  final bool isOvernight;       // 자정을 넘기는 일정 여부

  const ScheduleBlock({
    this.startTime,
    this.endTime,
    required this.rawText,
    this.isOvernight = false,
  });
}

/// ─── 날짜별로 묶인 하루 계획 데이터 구조 ──────────────────────────
class DayPlan {
  final String dateLabel;              // "2026년 4월 9일" 같은 날짜 원문 텍스트
  final List<ScheduleBlock> blocks;    // 그 날의 일정 덩어리들
  final List<String> memos;           // ``` 안에 있던 메모들

  const DayPlan({
    required this.dateLabel,
    required this.blocks,
    required this.memos,
  });
}

/// ─── 핵심 파싱 클래스 ──────────────────────────────────────────
class ScheduleParser {
  // ─── 시간 정규식 패턴들 (다양한 표현 방식 모두 인식) ────────────
  // 인식 가능한 형식들:
  //   "09시", "9시", "09:30", "9:30", "10시 30분", "오전 9시", "오후 3시 30분"
  //   "23시~01시", "10시30분~12시30분" (범위)
  static final RegExp _timePattern = RegExp(
    r'(?:오전|오후)?\s*'
    r'(\d{1,2})'
    r'(?:시간|시|:)'
    r'\s*'
    r'(\d{0,2})'
    r'(?:분)?'
    r'\s*(?:~|까지|부터)?',
    caseSensitive: false,
  );

  // ─── 날짜 줄 인식 패턴 ──────────────────────────────────────
  static final RegExp _dateLine = RegExp(
    r'\d{1,4}[.\-/년]?\s*\d{1,2}[.\-/월]?\s*\d{1,2}[일]?',
  );

  // ─── 메인 파싱 함수: 전체 텍스트 → 날짜별 계획 목록 ─────────────
  static List<DayPlan> parse(String fullText) {
    if (fullText.trim().isEmpty) return [];

    final List<DayPlan> result = [];
    String currentDateLabel = '';
    
    // 전체 텍스트를 메모 블록과 스케줄 블록으로 구분
    final chunks = fullText.split('```');

    List<ScheduleBlock> currentBlocks = [];
    List<String> currentMemos = [];

    void saveCurrentDay() {
      if (currentBlocks.isNotEmpty || currentMemos.isNotEmpty) {
        result.add(DayPlan(
          dateLabel: currentDateLabel.isEmpty ? '오늘' : currentDateLabel,
          blocks: currentBlocks,
          memos: currentMemos,
        ));
      }
    }

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final isMemoBlock = (i % 2 != 0);

      if (isMemoBlock) {
        // 💡 1. 백틱(```) 안쪽이면 무조건 메모로 저장!
        if (chunk.trim().isNotEmpty) {
          currentMemos.add(chunk.trim());
        }
      } else {
        // 💡 2. 일반 텍스트 영역이면 날짜/시간 스케줄 스캔
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (_isDateLine(line)) {
            // 날짜가 나오면 이전 날짜까지 모아둔 일정+메모를 정산
            saveCurrentDay();
            currentDateLabel = line.trim();
            currentBlocks = [];
            currentMemos = []; // 날짜가 바뀌었으므로 새 메모통 준비
          } else if (_hasTime(line)) {
            currentBlocks.add(_parseScheduleBlock(line));
          } else if (line.trim().isNotEmpty && currentBlocks.isNotEmpty) {
            // 시간이 명시되지 않은 줄은 직전 시간표에 설명으로 들러붙음
            final last = currentBlocks.last;
            currentBlocks[currentBlocks.length - 1] = ScheduleBlock(
              startTime: last.startTime,
              endTime: last.endTime,
              rawText: '${last.rawText}\n$line',
              isOvernight: last.isOvernight,
            );
          }
        }
      }
    }
    
    // 마지막 남은 자투리 데이터 모아서 저장
    saveCurrentDay();

    return result;
  }

  // ─── 한 줄에서 시작/종료 시간 파싱 ──────────────────────────
  static ScheduleBlock _parseScheduleBlock(String line) {
    // "~" 기호를 기준으로 시작~종료 분리
    final parts = line.split(RegExp(r'[~\-–]'));

    ParsedTime? startTime;
    ParsedTime? endTime;

    if (parts.isNotEmpty) {
      startTime = _extractFirstTime(parts[0]);
    }
    if (parts.length > 1) {
      endTime = _extractFirstTime(parts[1]);
    }

    // ─── 오버나이트 판단 로직 ──────────────────────────────────
    // 핵심 규칙: 시작 시간이 22시 이상이고, 종료 시간이 6시 미만이면 → 오버나이트!
    // (예: 23시~01시 → 다음날 새벽 1시이지만, 이 날의 일정으로 처리)
    bool isOvernight = false;
    if (startTime != null && endTime != null) {
      if (startTime.hour >= 22 && endTime.hour < 6) {
        isOvernight = true;
        // 오버나이트일 때 내부 계산용으로 종료 시간에 +24시간을 더함
        // (예: 23시~01시 → 종료를 25시로 계산해 올바른 알람 시간 확보)
        endTime = ParsedTime(hour: endTime.hour + 24, minute: endTime.minute);
      }
    }

    return ScheduleBlock(
      startTime: startTime,
      endTime: endTime,
      rawText: line,
      isOvernight: isOvernight,
    );
  }

  // ─── 문자열에서 첫 번째 시간 추출 ───────────────────────────
  static ParsedTime? _extractFirstTime(String text) {
    final match = _timePattern.firstMatch(text);
    if (match == null) return null;

    int hour = int.tryParse(match.group(1) ?? '') ?? -1;
    int minute = int.tryParse(match.group(2) ?? '0') ?? 0;

    // 24시/24:xx 입력은 다음 날 00시/00:xx로 자동 정규화합니다.
    if (hour == 24) {
      hour = 0;
    }

    if (hour < 0 || hour > 23) return null;

    // 오후 처리 (오후 3시 = 15시)
    if (text.contains('오후') && hour < 12) {
      hour += 12;
    }

    return ParsedTime(hour: hour, minute: minute);
  }

  // ─── 줄에 시간 표현이 포함되어 있는지 확인 ──────────────────
  static bool _hasTime(String line) {
    return _timePattern.hasMatch(line);
  }

  // ─── 날짜 줄인지 확인 ────────────────────────────────────
  static bool _isDateLine(String line) {
    final hasNumber = RegExp(r'\d').hasMatch(line);
    final hasDateKeyword = line.contains('년') ||
        line.contains('월') ||
        line.contains('일') && !line.contains('일정');
    return hasNumber && hasDateKeyword && _dateLine.hasMatch(line);
  }

  /// 현재 시각 기준으로 활성 날짜 섹션을 선택
  /// 규칙: 다음 날짜의 첫 일정 시작 30분 전부터 다음 날짜로 전환
  static DayPlan? pickActivePlan(List<DayPlan> dayPlans, {DateTime? now}) {
    if (dayPlans.isEmpty) return null;

    final nowTime = now ?? DateTime.now();
    DayPlan active = dayPlans.first;

    for (int i = 1; i < dayPlans.length; i++) {
      final nextPlan = dayPlans[i];
      final switchTime = _resolveSwitchTime(nextPlan, nowTime);

      if (nowTime.isBefore(switchTime)) {
        break;
      }
      active = nextPlan;
    }

    return active;
  }

  static DateTime _resolveSwitchTime(DayPlan plan, DateTime fallback) {
    final firstStart = _resolveFirstStartTime(plan, fallback);
    if (firstStart != null) {
      return firstStart.subtract(const Duration(minutes: 30));
    }

    final baseDate = resolvePlanDate(plan.dateLabel, fallback);
    return DateTime(baseDate.year, baseDate.month, baseDate.day);
  }

  static DateTime? _resolveFirstStartTime(DayPlan plan, DateTime fallback) {
    final baseDate = resolvePlanDate(plan.dateLabel, fallback);
    DateTime? first;

    for (final block in plan.blocks) {
      if (block.startTime == null) continue;
      final candidate = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        block.startTime!.hour,
        block.startTime!.minute,
      );
      if (first == null || candidate.isBefore(first)) {
        first = candidate;
      }
    }

    return first;
  }

  /// dateLabel 문자열을 실제 날짜로 변환
  /// 예) "2026년 4월 12일 계획", "4월 12일"
  static DateTime resolvePlanDate(String dateLabel, DateTime fallback) {
    final m = RegExp(r'(?:(\d{4})\D+)?(\d{1,2})\D+(\d{1,2})').firstMatch(dateLabel);
    if (m == null) {
      return DateTime(fallback.year, fallback.month, fallback.day);
    }

    final year = int.tryParse(m.group(1) ?? '') ?? fallback.year;
    final month = int.tryParse(m.group(2) ?? '') ?? fallback.month;
    final day = int.tryParse(m.group(3) ?? '') ?? fallback.day;

    return DateTime(year, month, day);
  }

  /// 오버나이트 블록이 끝나는 실제 DateTime 반환
  /// (다이제스트 알람 타이밍 계산에 사용)
  static DateTime? getOvernightEndTime(
    ScheduleBlock block,
    DateTime baseDate, // 기준 날짜 (일정이 속한 날)
  ) {
    if (!block.isOvernight || block.endTime == null) return null;

    final endHour = block.endTime!.hour; // 이미 +24 된 상태
    final actualHour = endHour - 24;    // 실제 표시 시간 (예: 1시)

    // 다음 날 새벽으로 DateTime 생성
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day + 1, // 하루 뒤
      actualHour,
      block.endTime!.minute,
    );
  }
}
