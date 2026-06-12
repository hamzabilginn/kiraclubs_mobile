import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/gradient_button.dart';
import '../home/main_nav_screen.dart';
import '../../services/notification_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _gender      = 'male';
  String _country     = 'TR';
  bool _obscurePass   = true;
  int _step           = 1; // 2-step register

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.register(
      name:     _nameCtrl.text.trim(),
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      gender:   _gender,
      country:  _country,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (_) => false,
      );
      Future.delayed(const Duration(milliseconds: 600), () {
        NotificationService.handlePendingNotification();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Kayıt başarısız.'),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                child: const Text('Hesap Oluştur',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 6),
              Text('Hızlıca kayıt ol ve keşfetmeye başla',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
              const SizedBox(height: 40),

              Form(
                key: _formKey,
                child: Column(children: [
                  // Ad Soyad
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      prefixIcon: Icon(Icons.person_outline, color: Color(0xFF9CA3AF)),
                    ),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'En az 2 karakter girin' : null,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF9CA3AF)),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Geçerli bir e-posta girin' : null,
                  ),
                  const SizedBox(height: 16),

                  // Şifre
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
                    validator: (v) => (v == null || v.length < 6)
                        ? 'En az 6 karakter girin' : null,
                  ),
                  const SizedBox(height: 24),

                  // Cinsiyet Seçimi
                  Text('Cinsiyet', style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _GenderChip(
                      label: '👨 Erkek',
                      selected: _gender == 'male',
                      onTap: () => setState(() => _gender = 'male'),
                    ),
                    const SizedBox(width: 12),
                    _GenderChip(
                      label: '👩 Kadın',
                      selected: _gender == 'female',
                      onTap: () => setState(() => _gender = 'female'),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Ülke
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderCol, width: 1.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _country,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E1B2E),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9CA3AF)),
                        onChanged: (v) => setState(() => _country = v ?? 'TR'),
                        items: const [
                          DropdownMenuItem(value: 'TR', child: Text('🇹🇷 Türkiye')),
                          DropdownMenuItem(value: 'RU', child: Text('🇷🇺 Rusya')),
                          DropdownMenuItem(value: 'AZ', child: Text('🇦🇿 Azerbaycan')),
                          DropdownMenuItem(value: 'KZ', child: Text('🇰🇿 Kazakistan')),
                          DropdownMenuItem(value: 'UZ', child: Text('🇺🇿 Özbekistan')),
                          DropdownMenuItem(value: 'DE', child: Text('🇩🇪 Almanya')),
                          DropdownMenuItem(value: 'US', child: Text('🇺🇸 ABD')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  GradientButton(
                    text: 'Hesap Oluştur',
                    onPressed: auth.isLoading ? null : _submit,
                    isLoading: auth.isLoading,
                  ),
                ]),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Kayıt olarak Gizlilik Politikamızı\nve Kullanım Şartlarımızı kabul etmiş olursunuz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.primaryGradient : null,
            color: selected ? null : const Color(0xFF1E1B2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.transparent : AppTheme.borderCol,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              )),
          ),
        ),
      ),
    );
  }
}
