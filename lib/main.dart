import 'dart:io' show Platform, File;
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'screens/home_screen.dart';
import 'screens/memo_board_screen.dart';
import 'screens/alarm_center_screen.dart';
import 'engine/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 (앱 시작 시 한 번만 실행)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 알림 서비스 초기화 (타임존 설정 등)
  await NotificationService.initialize();

  // 상태바 색상을 핑크 테마에 맞게 조정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 윈도우 환경인 경우 트레이 아이콘을 위해 앱 닫힘(Destroy) 방지 설정
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow(const WindowOptions(), () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setPreventClose(true); // X를 눌러도 강제 종료 안 됨 (숨김 처리용)
    });
  }

  runApp(const TtaSchedulerApp());
}

class TtaSchedulerApp extends StatelessWidget {
  const TtaSchedulerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: globalMessengerKey, // 알람 인앱 팝업용
      title: '윤준식 스케줄러 💕',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainShell(),
    );
  }
}

/// 전체 앱 껍데기 - 탭 내비게이션 관리
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WindowListener, TrayListener {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.requestPermissionsOnAppStart();
    });

    if (Platform.isWindows) {
      windowManager.addListener(this);
      _initSystemTray();
    }
  }

  Future<void> _initSystemTray() async {
    // 윈도우용 트레이 아이콘 설정 (절대 경로 방식으로 정밀화)
    String iconPath = '';
    if (Platform.isWindows) {
      // 1. 실행파일의 절대 위치를 파악하여 그 옆의 아이콘을 가리킴
      final exeDir = p.dirname(Platform.resolvedExecutable);
      iconPath = p.join(exeDir, 'app_icon.ico');
    }

    try {
      if (await File(iconPath).exists()) {
        await trayManager.setIcon(iconPath);
      } else {
        // 개발 환경 폴백
        await trayManager.setIcon('windows/runner/resources/app_icon.ico');
      }
    } catch (_) {
      // 최후의 보루 (비둘기라도 뜨게 함)
    }
    
    // 트레이 마우스 호버 시 뜰 이름 설정
    await trayManager.setToolTip('윤준식 스케줄러');

    // 트레이 우클릭 메뉴
    final List<MenuItem> items = [
      MenuItem(key: 'show_window', label: '윤준식 스케줄러 열기'),
      MenuItem.separator(),
      MenuItem(key: 'exit_app', label: '완전히 종료'),
    ];
    await trayManager.setContextMenu(Menu(items: items));
    trayManager.addListener(this);
  }

  // 트레이 아이콘 클릭 시
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  // 트레이 우클릭 시
  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  // 트레이 메뉴 항목 선택 시
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy(); // 이때만 실제로 앱을 종료
    }
  }

  // [X] 버튼을 눌렀을 때 앱을 끄지 않고 숨김 처리
  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      windowManager.hide();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    MemoBoardScreen(),
    AlarmCenterScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;

    return isWide ? _buildDesktopLayout() : _buildMobileLayout();
  }

  /// 데스크톱: 왼쪽 고정 사이드바
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.backgroundPink,
      body: Row(
        children: [
          // 왼쪽 사이드바
          _buildSidebar(),
          // 오른쪽 화면 content
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.sidebarPink,
        border: Border(
          right: BorderSide(color: AppColors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 사이드바 로고 영역
          const SizedBox(height: 40),
          const Text('💕', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          const Text(
            '윤준식 스케줄러',
            style: TextStyle(
              color: AppColors.deepRose,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '쓰던 습관 그대로 ✨',
            style: TextStyle(
              color: AppColors.textGray.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 32),
          Divider(color: AppColors.divider, indent: 20, endIndent: 20),
          const SizedBox(height: 8),
          // 네비게이션 메뉴 아이템들
          _sidebarItem(0, Icons.edit_note_rounded, '계획 에디터'),
          _sidebarItem(1, Icons.sticky_note_2_rounded, '메모 보드'),
          _sidebarItem(2, Icons.notifications_rounded, '알림 센터'),
          const Spacer(),
          // 하단 버전 표시
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'ver 0.1.0 💕',
              style: TextStyle(
                color: AppColors.textGray.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPink.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: AppColors.primaryPink.withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryPink : AppColors.textGray,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.deepRose : AppColors.textGray,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPink,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 모바일: 하단 탭바
  Widget _buildMobileLayout() {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomTabBar(),
    );
  }

  Widget _buildBottomTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sidebarPink,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tabItem(0, Icons.edit_note_rounded, '에디터'),
              _tabItem(1, Icons.sticky_note_2_rounded, '메모'),
              _tabItem(2, Icons.notifications_rounded, '알림'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPink.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryPink : AppColors.textGray,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primaryPink : AppColors.textGray,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
