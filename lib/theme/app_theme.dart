import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansKR', // 추후 pubspec에 추가
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryPink,
        surface: AppColors.backgroundPink,
        primary: AppColors.primaryPink,
        secondary: AppColors.lightPink,
      ),
      scaffoldBackgroundColor: AppColors.backgroundPink,

      // 앱바 스타일
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.sidebarPink,
        foregroundColor: AppColors.deepRose,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.deepRose,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),

      // 텍스트 테마
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: AppColors.textDark,
          fontSize: 15,
          height: 1.8,
          letterSpacing: 0.1,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textDark,
          fontSize: 14,
          height: 1.7,
        ),
        titleLarge: TextStyle(
          color: AppColors.dateTextColor,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),

      // 기본 버튼 스타일 (둥글고 핑크)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPink,
          foregroundColor: AppColors.textOnPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: 2,
        ),
      ),

      // 하단 탭바 스타일
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.sidebarPink,
        selectedItemColor: AppColors.primaryPink,
        unselectedItemColor: AppColors.textGray,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      // 구분선
      dividerColor: AppColors.divider,
    );
  }
}
