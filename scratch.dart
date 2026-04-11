import 'lib/engine/schedule_parser.dart';

void main() {
  final text = '''
2026년 4월 11일
10시 30분 미팅
```
메모메모메모
```
''';
  final result = ScheduleParser.parse(text);
  print('DayPlans: ${result.length}');
  for (var plan in result) {
    print('Date: ${plan.dateLabel}');
    print('Memos: ${plan.memos}');
    print('Alarms: ${plan.blocks.length}');
  }
}
