import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/gradient_button.dart';
import '../home/main_nav_screen.dart';
import 'register_screen.dart';
import '../../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePass   = true;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
  }

  void _initDeepLinkListener() {
    _appLinks = AppLinks();
    
    // Check initial link if app was closed and opened via deep link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Listen to incoming links when app is in background/foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      print("Deep link listener error: $err");
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    print("Received Deep Link: $uri");
    if (uri.scheme == 'kiraclubs' && uri.host == 'auth' && uri.path == '/callback') {
      final token = uri.queryParameters['token'];
      final userDataEncoded = uri.queryParameters['user'];
      
      if (token != null && userDataEncoded != null) {
        try {
          final userDataDecoded = Uri.decodeComponent(userDataEncoded);
          final userJson = jsonDecode(userDataDecoded);
          
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.loginWithTokenAndUser(token, userJson);
          
          if (!mounted) return;
          if (auth.isAuthenticated) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainNavScreen()),
            );
            Future.delayed(const Duration(milliseconds: 600), () {
              NotificationService.handlePendingNotification();
            });
          }
        } catch (e) {
          print("Error processing deep link user data: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Sosyal giriş bilgileri işlenirken bir hata oluştu.'),
              backgroundColor: Colors.red,
            ));
          }
        }
      }
    }
  }

  Future<void> _launchSocialAuth(String provider) async {
    final url = Uri.parse('https://www.kiraclubs.com/auth/redirect/$provider?platform=mobile');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      print("Social auth launch error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$provider giriş sayfası açılamadı.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok   = await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
      );
      Future.delayed(const Duration(milliseconds: 600), () {
        NotificationService.handlePendingNotification();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Giriş başarısız.'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      blurRadius: 20, spreadRadius: 2,
                    )],
                  ),
                  child: const Center(child: Text('K',
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white))),
                ),
              ),
              const SizedBox(height: 32),
              ShaderMask(
                shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                child: const Text('Hoş geldin!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 6),
              Text('Hesabına giriş yap',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF9CA3AF)),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Geçerli bir e-posta girin' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePass,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF9CA3AF)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF9CA3AF),
                        ),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'En az 6 karakter girin' : null,
                  ),
                  const SizedBox(height: 32),
                  GradientButton(
                    text: 'Giriş Yap',
                    onPressed: auth.isLoading ? null : _submit,
                    isLoading: auth.isLoading,
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              if (!Platform.isIOS) ...[
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.08), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('veya sosyal medya ile giriş yapın', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.08), thickness: 1)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialLoginButton(
                      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                      label: 'Google',
                      onTap: auth.isLoading ? null : () => _launchSocialAuth('google'),
                    ),
                    const SizedBox(width: 12),
                    _buildSocialLoginButton(
                      iconUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Ionicons_logo-tiktok.svg/24px-Ionicons_logo-tiktok.svg.png',
                      label: 'TikTok',
                      iconColor: Colors.white,
                      onTap: auth.isLoading ? null : () => _launchSocialAuth('tiktok'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: RichText(
                    text: TextSpan(
                      text: 'Hesabın yok mu? ',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      children: [TextSpan(
                        text: 'Kayıt Ol',
                        style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                      )],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSocialCard(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFEC4899).withOpacity(0.05),
            const Color(0xFF8B5CF6).withOpacity(0.05),
            const Color(0xFF6366F1).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sosyal Medyada Bizi Takip Edin!',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Yeniliklerden haberdar olmak ve bizimle iletişime geçin.',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final url = Uri.parse('https://instagram.com/kiraclubsss');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('📸 Instagram', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final url = Uri.parse('https://tiktok.com/@kiraclubss');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  child: const Text('🎵 TikTok', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLoginButton({
    required String iconUrl,
    required String label,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1E1B2E).withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              iconUrl,
              height: 16,
              width: 16,
              color: iconColor,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.login, size: 16, color: Colors.white);
              },
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData iconData;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({required this.iconData, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderCol, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
