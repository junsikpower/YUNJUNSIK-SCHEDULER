import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Firestore 서비스
/// - 에디터의 텍스트를 클라우드에 저장하고 불러오는 역할
/// - 인터넷이 없을 때는 로컬(shared_preferences)에 임시 저장
class FirestoreService {
  // Firestore 인스턴스 (구글 클라우드 DB 접속 객체)
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 문서 경로: schedules > (사용자ID) > entries
  // 지금은 단일 사용자로 "user_default" 로 고정 (추후 로그인 연동 시 변경)
  static const String _userId = 'user_default';
  static const String _localKey = 'tta_draft_text'; // 로컬 임시저장 키

  // ─── 텍스트 전체를 Firestore에 저장 ───────────────────────────────
  // docId: 날짜 문자열 (예: "2026-04-11") 또는 커스텀 ID
  static Future<void> saveScheduleText({
    required String docId,
    required String text,
  }) async {
    try {
      await _db
          .collection('schedules')
          .doc(_userId)
          .collection('entries')
          .doc(docId)
          .set({
        'text': text,
        'updatedAt': FieldValue.serverTimestamp(), // 마지막 수정 시각 자동 기록
      }, SetOptions(merge: true)); // 기존 내용은 유지하고 덮어쓰기

      // 파이어베이스 저장 성공 시 로컬 캐시도 동기화
      await _saveLocal(text);
    } catch (e) {
      // 인터넷 오류가 나도 최소한 로컬에는 저장
      await _saveLocal(text);
      rethrow; // 에러를 상위로 전달 (UI에서 처리)
    }
  }

  // ─── 오늘 날짜 문서를 Firestore에서 불러오기 ────────────────────
  static Future<String?> loadTodayText() async {
    final today = _todayDocId();
    return loadScheduleText(docId: today);
  }

  // ─── 특정 날짜 문서를 Firestore에서 불러오기 ────────────────────
  static Future<String?> loadScheduleText({required String docId}) async {
    try {
      final snapshot = await _db
          .collection('schedules')
          .doc(_userId)
          .collection('entries')
          .doc(docId)
          .get();

      if (snapshot.exists) {
        return snapshot.data()?['text'] as String?;
      }
      return null;
    } catch (e) {
      // 인터넷 오류 시 로컬 캐시에서 불러오기
      return _loadLocal();
    }
  }

  // ─── 실시간 스트림: 문서가 변경될 때마다 자동으로 알림 ───────────
  // (나중에 같은 계정으로 여러 기기에서 실시간 동기화할 때 사용)
  static Stream<String?> watchTodayText() {
    final today = _todayDocId();
    return _db
        .collection('schedules')
        .doc(_userId)
        .collection('entries')
        .doc(today)
        .snapshots()
        .map((snap) => snap.data()?['text'] as String?);
  }

  // ─── 오늘 날짜 ID 생성 (예: "2026-04-11") ────────────────────
  static String _todayDocId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ─── 로컬 임시 저장 ──────────────────────────────────────────
  static Future<void> _saveLocal(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, text);
  }

  // ─── 로컬에서 불러오기 ──────────────────────────────────────
  static Future<String?> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localKey);
  }

  // ─── 드래프트(임시저장) 로컬에만 조용히 저장 ─────────────────────
  static Future<void> saveDraft(String text) async {
    await _saveLocal(text);
  }

  // ─── 앱 시작 시 마지막으로 작성하던 내용 복원 ──────────────────
  static Future<String?> loadLastDraft() async {
    // Firestore 오늘치 먼저 시도, 실패하면 로컬 반환
    final fromCloud = await loadTodayText();
    if (fromCloud != null && fromCloud.isNotEmpty) return fromCloud;
    return _loadLocal();
  }
}
