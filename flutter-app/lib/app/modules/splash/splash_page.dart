import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health_center_app/core/storage/storage_service.dart';

/// 启动页
/// 设计理念：简洁、专业、健康主题
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _initApp();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  Future<void> _initApp() async {
    // 等待动画完成后再跳转
    await Future.delayed(const Duration(milliseconds: 800));

    // 模拟初始化过程
    await Future.delayed(const Duration(milliseconds: 1200));

    final storage = Get.find<StorageService>();

    // 根据登录状态跳转
    if (storage.isLoggedIn) {
      Get.offAllNamed('/home');
    } else {
      Get.offAllNamed('/login');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E9), // 极浅绿 - 柔和清新
              Color(0xFFC8E6C9), // 浅绿色 - 温暖舒适
              Color(0xFFA5D6A7), // 中浅绿 - 自然和谐
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo 动画
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: _buildLogo(),
              ),
              const SizedBox(height: 32),

              // App 名称
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  );
                },
                child: const Text(
                  '家庭健康中心',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32), // 深绿色文字
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 英文副标题
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value * 0.9,
                    child: child,
                  );
                },
                child: const Text(
                  'Family Health Center',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4CAF50), // 主绿色文字
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Slogan
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value * 0.8,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    '一人管理，全家受益',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 64),

              // 版本号显示
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'v2.1.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF4CAF50).withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              // 加载指示器
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  );
                },
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4CAF50),
                    ),
                    backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建 Logo 组件
  Widget _buildLogo() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 0),
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景圆环
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                width: 2,
              ),
            ),
          ),
          // 心形图标
          Icon(
            Icons.favorite_rounded,
            size: 70,
            color: Colors.green.shade400,
          ),
          // 脉搏线装饰
          Positioned(
            bottom: 20,
            child: Container(
              width: 60,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CustomPaint(
                painter: _ECGPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 心电图绘制器
class _ECGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    const startX = 5.0;
    final baseline = size.height / 2;

    path.moveTo(startX, baseline);

    // P波
    path.lineTo(12, baseline - 3);
    path.lineTo(16, baseline);

    // QRS复合波
    path.lineTo(20, baseline + 5);
    path.lineTo(25, baseline - 12);
    path.lineTo(30, baseline + 8);
    path.lineTo(35, baseline);

    // T波
    path.lineTo(42, baseline - 4);
    path.lineTo(48, baseline);

    // 延续线
    path.lineTo(size.width, baseline);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
