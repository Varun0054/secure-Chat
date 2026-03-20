import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../controller/login_controller.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final LoginController _controller = LoginController();
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.session != null) {
        final user = data.session!.user;
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (mounted) {
            if (profile != null && profile['username'] != null && profile['username'].toString().isNotEmpty) {
              Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
            } else {
              Navigator.pushNamedAndRemoveUntil(context, '/create_username', (route) => false);
            }
          }
        } catch (e) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/create_username', (route) => false);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We use a Stack to layer the "Glowing Orbs" behind the content
    return Scaffold(
      backgroundColor: const Color(0xFF0F1223),
      body: Stack(
        children: [
          // 1. Background Elements (Replacing Image Assets)
          const _BackgroundOrbs(),

          // 2. Foreground Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Logo / Icon Section
                  const _HeroIcon(),

                  const SizedBox(height: 40),

                  // Title Section
                  Column(
                    children: [
                      Text(
                        'Welcome to',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 20,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'SecureChat',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildBetaTag(),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Subtitle
                  Text(
                    'Chat securely\nwith full privacy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Buttons Section
                  _AuthButton(
                    label: 'Continue with Google',
                    // Using a Text "G" to simulate the logo without assets
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'serif',
                      ),
                    ),
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    onPressed: _controller.onGoogleLogin,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'or',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),

                  const SizedBox(height: 16),

                  _AuthButton(
                    label: 'Login with Email',
                    icon: const Icon(Icons.login, size: 22),
                    backgroundColor: const Color(0xFF1E2235),
                    textColor: Colors.white,
                    onPressed: () => Navigator.pushNamed(context, '/signin'),
                  ),

                  const SizedBox(height: 16),

                  _AuthButton(
                    label: 'Signup with Email',
                    icon: const Icon(Icons.email_outlined, size: 22),
                    backgroundColor: const Color(0xFF1E2235), // Darker surface
                    textColor: Colors.white,
                    onPressed: () => _controller.navigateToSignup(context),
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetaTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent.withValues(alpha: 0.4),
            Colors.purpleAccent.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Text(
        'BETA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// --- Custom Components ---

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: const Icon(
        Icons.chat_bubble_outline_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onPressed;

  const _AuthButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: backgroundColor == Colors.white
                ? BorderSide.none
                : BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundOrbs extends StatelessWidget {
  const _BackgroundOrbs();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top Left Purple Orb
        Positioned(
          top: -100,
          left: -50,
          child: _GlowingOrb(
            color: const Color(0xFF7B61FF).withValues(alpha: 0.3),
            radius: 200,
          ),
        ),
        // Center Right Blue Orb
        Positioned(
          top: 100,
          right: -80,
          child: _GlowingOrb(
            color: const Color(0xFF2FA4FF).withValues(alpha: 0.2),
            radius: 180,
          ),
        ),
        // Bottom Center Subtle glow
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: _GlowingOrb(
              color: const Color(0xFF7B61FF).withValues(alpha: 0.1),
              radius: 300,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowingOrb extends StatelessWidget {
  final Color color;
  final double radius;

  const _GlowingOrb({required this.color, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      // This backdrop filter creates the blurred, glowing nebula effect
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 0.7],
          ),
        ),
      ),
    );
  }
}
