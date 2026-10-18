import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/utils/al_version_utils.dart';
import '../../foundations/navigation/al_router.dart';
import '../../foundations/navigation/al_routes.dart';
import '../../foundations/log/al_logger.dart';
import '../../foundations/ui/vvewell_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// App splash page - a simple transition animation page
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final AlRouter _router = AlRouter();
  String _versionString = 'Version 1.0.0';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadVersionInfo();
    _startAnimationSequence();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// Initialize the animation controllers
  void _initAnimations() {
    // Fade-in animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Scale animation controller
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Fade-in animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Scale animation
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
  }

  /// Start the animation sequence and SDK initialization
  Future<void> _startAnimationSequence() async {
    try {
      // Delay briefly before starting the animation
      await Future.delayed(const Duration(milliseconds: 200));

      // Start the fade-in and scale animations simultaneously
      _fadeController.forward();
      _scaleController.forward();

      // Wait for the animation to finish displaying
      await _waitForAnimationComplete();

      // Navigate to the home page
      _navigateToHome();
    } catch (e) {
      if (kDebugMode) {
        print('Error in splash sequence: $e');
      }
      // Navigate to the home page even on error
      _navigateToHome();
    }
  }

  /// Wait for the animation to complete
  Future<void> _waitForAnimationComplete() async {
    // Wait an additional period after the animation completes
    await Future.delayed(const Duration(milliseconds: 1800));
  }

  /// Load version information
  Future<void> _loadVersionInfo() async {
    final versionString = await AlVersionUtils.getDisplayVersion();
    if (mounted) {
      setState(() {
        _versionString = versionString;
      });
    }
  }

  /// Navigate to the home page
  void _navigateToHome() {
    if (mounted) {
      AlLogger.info('Navigating to main navigation page', tag: 'SPLASH_PAGE');

      _router.offAllNamed(AlRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VvewellColors.background,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildContent(context),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build the page content
  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Brand logo
        _buildAppLogo(context),

        SizedBox(height: 28.h),

        // Welcome text
        _buildWelcomeText(),

        SizedBox(height: 40.h),

        // Loading indicator
        _buildLoadingIndicator(),

        SizedBox(height: 48.h),

        // Version info
        _buildVersionInfo(),
      ],
    );
  }

  /// Build the app logo (company brand mark)
  Widget _buildAppLogo(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 34.w),
      child: Image.asset(
        'assets/images/vvewell-logo.png',
        width: 310.w,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  /// Build the loading indicator
  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 22.w,
      height: 22.h,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: const AlwaysStoppedAnimation<Color>(VvewellColors.primary),
      ),
    );
  }

  /// Build the welcome text
  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          "Health management platform",
          style: TextStyle(
            fontSize: 14.sp,
            color: VvewellColors.muted,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  /// Build the version info
  Widget _buildVersionInfo() {
    return Column(
      children: [
        Text(
          _versionString,
          style: TextStyle(fontSize: 12.sp, color: VvewellColors.muted),
        ),
        if (kDebugMode) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: Text(
              'DEBUG',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
