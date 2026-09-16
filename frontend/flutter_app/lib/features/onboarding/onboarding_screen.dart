import 'package:flutter/material.dart';
import '../../core/theme/vr_colors.dart';
import '../../core/theme/vr_typography.dart';
import '../../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium 3-step onboarding experience for VANIRAKSHAK.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardingData(
      title: 'Your voice.\nYour identity.\nProtected.',
      subtitle: 'Protection against AI voice cloning and impersonation scams.',
      icon: Icons.shield_outlined,
      cta: 'Get Protected',
    ),
    _OnboardingData(
      title: 'Same voice.\nDifferent intent.',
      subtitle: 'Scammers can imitate voices and manipulate conversations. We detect the difference.',
      icon: Icons.graphic_eq_rounded,
      cta: 'Next',
    ),
    _OnboardingData(
      title: 'We listen for\nthe warning signs.',
      subtitle: null,
      icon: Icons.security_rounded,
      cta: 'Start Protection',
      capabilities: ['Detect', 'Understand', 'Verify', 'Protect'],
    ),
  ];

  Future<void> _next() async {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefOnboardingDone, true);
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),
            // Page dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i ? VrColors.primary : VrColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: FilledButton(
                onPressed: _next,
                child: Text(_pages[_page].cta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingData {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String cta;
  final List<String>? capabilities;

  const _OnboardingData({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.cta,
    this.capabilities,
  });
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shield / icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VrColors.primary.withValues(alpha: 0.08),
              border: Border.all(color: VrColors.primary.withValues(alpha: 0.2), width: 2),
            ),
            child: Icon(data.icon, size: 44, color: VrColors.primary),
          ),
          const SizedBox(height: 40),
          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: VrTypography.hero.copyWith(color: VrColors.textPrimary),
          ),
          const SizedBox(height: 16),
          // Subtitle or capabilities
          if (data.subtitle != null)
            Text(
              data.subtitle!,
              textAlign: TextAlign.center,
              style: VrTypography.body.copyWith(color: VrColors.textSecondary),
            ),
          if (data.capabilities != null) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: data.capabilities!
                  .map((cap) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: VrColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: VrColors.borderSubtle),
                        ),
                        child: Text(cap,
                            style: VrTypography.label.copyWith(color: VrColors.primary)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
