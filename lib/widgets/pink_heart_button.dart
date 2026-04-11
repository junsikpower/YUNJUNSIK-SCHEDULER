import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 핑크 하트 둥근 버튼 위젯
/// onPressed: 눌렀을 때 실행할 함수
/// label: 버튼 안에 표시할 글자
/// icon: 버튼 왼쪽에 들어갈 아이콘 (선택사항)
class PinkHeartButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final bool isSmall;

  const PinkHeartButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isSmall = false,
  });

  @override
  State<PinkHeartButton> createState() => _PinkHeartButtonState();
}

class _PinkHeartButtonState extends State<PinkHeartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) {
    _controller.reverse();
    widget.onPressed();
  }
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSmall ? 14 : 20,
            vertical: widget.isSmall ? 8 : 12,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.lightPink, AppColors.primaryPink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPink.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: AppColors.textOnPrimary,
                  size: widget.isSmall ? 14 : 18,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: widget.isSmall ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
