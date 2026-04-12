# TODO(release-opt): R8(minify) 재활성화 시 이 파일을 함께 점검할 것.
# TODO(release-opt): 알림 관련 keep rule이 부족하면 릴리즈에서 알림이 누락될 수 있음.
# TODO(release-opt): 최적화 재적용 후 알림/권한/부팅 후 재예약 회귀 테스트 필수.

# flutter_local_notifications 관련 클래스 보호
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Firebase 관련 클래스 보호 (필요시)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# 알림에 필요한 기본 안드로이드 클래스 유지
-keep class android.app.Notification { *; }
-keep class android.app.NotificationManager { *; }
