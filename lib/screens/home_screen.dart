import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/tta_text_painter.dart';
import '../widgets/pink_heart_button.dart';
import '../engine/firestore_service.dart';
import '../engine/schedule_parser.dart';
import '../engine/notification_service.dart';

/// 메인 에디터 화면
/// - 왼쪽: 사용자가 줄글을 자유롭게 타이핑하는 입력창
/// - 오른쪽 (데스크톱): 실시간으로 시각화된 결과 미리보기 (노란박스, 날짜 굵게)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<String?>? _todayTextSub;
  String _currentText = '';
  bool _isSaving = false;       // 저장 중 여부
  bool _isLoading = true;       // 불러오는 중 여부
  List<DayPlan> _parsedPlans = []; // 파싱된 일정 목록

  // 처음 실행 시 보여줄 안내 예시 텍스트
  static const String _placeholderText =
      '2026년 4월 9일 계획\n'
      '09시 기상\n'
      '10시 30분~13시 형이상학 수업\n'
      '```\n'
      '수업 준비물: 교재, 필기도구\n'
      '```\n'
      '23시 30분~01시 30분 휴식';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _currentText = _controller.text;
        // 텍스트가 바뀔 때마다 파싱 엔진 실행
        _parsedPlans = ScheduleParser.parse(_currentText);
      });
    });
    // 앱 시작 시 이전에 저장한 내용 자동 불러오기
    _loadSavedText();
    _startCloudSyncForAlarms();
  }

  // ─── 저장된 텍스트 불러오기 ─────────────────────────────────
  Future<void> _loadSavedText() async {
    try {
      final saved = await FirestoreService.loadLastDraft();
      if (saved != null && saved.isNotEmpty && mounted) {
        _controller.text = saved;
        await NotificationService.scheduleAlarms(ScheduleParser.parse(saved));
      }
    } catch (_) {
      // 불러오기 실패해도 앱은 계속 실행
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── 클라우드 변경 감지 시 각 기기에서 알림 자동 재예약 ─────────────
  void _startCloudSyncForAlarms() {
    _todayTextSub = FirestoreService.watchTodayText().listen((incomingText) async {
      if (incomingText == null || incomingText.isEmpty || !mounted) return;

      try {
        // 다른 기기에서 저장된 텍스트를 현재 에디터에도 반영
        if (_controller.text != incomingText) {
          _controller.text = incomingText;
        }

        // 핵심: 클라우드 텍스트 변경 시 이 기기에서도 시스템 알림 재예약
        await NotificationService.scheduleAlarms(ScheduleParser.parse(incomingText));
      } catch (_) {
        // 스트림 콜백 예외로 앱이 종료되지 않도록 보호
      }
    });
  }

  // ─── 저장 버튼 동작 ─────────────────────────────────────────
  Future<void> _onSave() async {
    if (_isSaving || _currentText.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final today = DateTime.now();
      final docId =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await FirestoreService.saveScheduleText(
        docId: docId,
        text: _currentText,
      );

      // 💡 저장 성공 시, 백그라운드 & 인앱 실제 알람 스케줄 예약
      await NotificationService.scheduleAlarms(_parsedPlans);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('💕일정이 저장됐어요!'),
            backgroundColor: AppColors.primaryPink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로컬에만 임시저장됐어요 (인터넷 확인 필요)'),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _todayTextSub?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: AppColors.backgroundPink,
      appBar: _buildAppBar(),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.sidebarPink,
      elevation: 0,
      title: Row(
        children: const [
          Text('💕', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text(
            '윤준식 스케줄러',
            style: TextStyle(
              color: AppColors.deepRose,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryPink,
                    ),
                  ),
                )
              : PinkHeartButton(
                  label: '저장',
                  icon: Icons.favorite,
                  isSmall: true,
                  onPressed: _onSave, // 이제 진짜 파이어베이스에 저장!
                ),
        ),
      ],
    );
  }

  /// 데스크톱: 좌우 2분할
  Widget _buildWideLayout() {
    return Row(
      children: [
        // 왼쪽: 에디터 입력창
        Expanded(
          flex: 5,
          child: _buildEditor(),
        ),
        // 구분선
        Container(
          width: 1,
          color: AppColors.divider,
        ),
        // 오른쪽: 실시간 미리보기
        Expanded(
          flex: 4,
          child: _buildPreviewPanel(),
        ),
      ],
    );
  }

  /// 모바일: 에디터만
  Widget _buildNarrowLayout() {
    return _buildEditor();
  }

  /// 실제 글쓰기 에디터 영역
  Widget _buildEditor() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.editorSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        children: [
          // 에디터 상단 라벨
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.sidebarPink.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: const [
                Icon(Icons.edit_note, color: AppColors.deepRose, size: 18),
                SizedBox(width: 8),
                Text(
                  '오늘의 계획을 자유롭게 써보세요 ✍️',
                  style: TextStyle(
                    color: AppColors.deepRose,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // 텍스트 입력창
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15,
                  height: 1.8,
                  letterSpacing: 0.1,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _placeholderText,
                  hintStyle: TextStyle(
                    color: AppColors.textGray.withOpacity(0.5),
                    fontSize: 14,
                    height: 1.8,
                  ),
                ),
              ),
            ),
          ),
          // 하단 힌트 바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.sidebarPink.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _hintChip('📅 날짜 → 자동 굵게'),
                _hintChip('📝 ``` → 메모 인식'),
                _hintChip('🌙 23시→01시 자동 인식'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sidebarPink,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.deepRose,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 데스크톱 오른쪽 실시간 미리보기 Panel
  Widget _buildPreviewPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.editorSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        children: [
          // 미리보기 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.sidebarPink.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: const [
                Text('✨', style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Text(
                  '실시간 시각화 미리보기',
                  style: TextStyle(
                    color: AppColors.deepRose,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // 실시간 렌더링 결과
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _currentText.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Text(
                            '💕',
                            style: TextStyle(
                              fontSize: 48,
                              color: AppColors.primaryPink.withOpacity(0.3),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '왼쪽에 계획을 쓰면\n여기서 예쁘게 변환됩니다',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textGray.withOpacity(0.7),
                              fontSize: 13,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TtaTextPainter(text: _currentText),
            ),
          ),
        ],
      ),
    );
  }
}
