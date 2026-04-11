import 'package:flutter/material.dart';

class AppColors {
  // 배경 색상 (파스텔 핑크 계열)
  static const Color backgroundPink = Color(0xFFFFF0F5); // 연한 라벤더블러쉬 배경
  static const Color sidebarPink = Color(0xFFFFDDE8);    // 사이드바/탭바 파스텔 핑크
  static const Color editorSurface = Color(0xFFFFFAFC);  // 에디터 흰색에 가까운 표면

  // 포인트 색상 (핫핑크/코랄 계열)
  static const Color primaryPink = Color(0xFFE91E8C);    // 핫핑크 (주요 버튼/포인트)
  static const Color lightPink = Color(0xFFFF6EB4);      // 코랄 핑크 (보조 버튼)
  static const Color deepRose = Color(0xFFC2185B);       // 딥로즈 (텍스트 포인트)

  // 날짜 굵게 처리 색상
  static const Color dateTextColor = Color(0xFFAD1457);  // 로즈 다크 (날짜 제목 색상)

  // 메모 하이라이트 (노란색 박스)
  static const Color memoHighlight = Color(0xFFFFFDE7);  // 연한 노란색 배경
  static const Color memoHighlightBorder = Color(0xFFFFF176); // 노란 테두리

  // 텍스트
  static const Color textDark = Color(0xFF3D1A2E);       // 에디터 기본 글씨 (다크 로즈)
  static const Color textGray = Color(0xFF9E9E9E);       // 보조 텍스트 회색
  static const Color textOnPrimary = Colors.white;       // 버튼 위 흰 글씨

  // 선 / 구분선
  static const Color divider = Color(0xFFFFB6C1);        // 연핑크 구분선
}
