import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({Key? key}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final ApiService _api = ApiService();
  bool _isSecretMode = false;
  bool _notificationsOn = true;

  Future<void> _logout(AuthProvider auth) async {
    await auth.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final referralCode = user.referralCode ?? 'KIRA${user.id}';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        title: const Text('Profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simple Profile Header
            _buildProfileHeader(user),
            const SizedBox(height: 20),

            // 1. Referans Kodun
            _buildReferralCard(referralCode),
            const SizedBox(height: 16),

            // 2. Sosyal Medya
            _buildSocialCard(),
            const SizedBox(height: 20),

            // 3. Hakkımda
            _buildAboutCard(user),
            const SizedBox(height: 20),

            // 4. Gizli Profil Modu
            _buildSecretModeCard(user),
            const SizedBox(height: 16),

            // 5. Bildirimler Açık
            _buildNotificationsCard(),
            const SizedBox(height: 16),

            // 6. Mavi Tik (Profil Doğrulama)
            _buildVerificationCard(user),
            const SizedBox(height: 16),

            // 7. Ajans Yönetim Paneli
            if (user.isAgencyOwner || user.isPublisher) ...[
              _buildAgencyButton(),
              const SizedBox(height: 16),
            ],

            // 8. Destek Taleplerim
            _buildSupportCard(),
            const SizedBox(height: 24),

            // 9. Çıkış Button
            _buildLogoutButton(auth),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    final String? avatarUrl = user.avatarUrl;
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppTheme.cardColor,
          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
          child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 36) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                user.rankName,
                style: const TextStyle(color: AppTheme.accentColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 16),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReferralCard(String code) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                      child: const Text(
                        'Referans Kodun',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Arkadaşlarını davet et — Mavi Tik alınca ikiniz de 10 Kredi kazanın! 🔵',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0A10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderCol),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Referans kodu kopyalandı! 📋'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                    child: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Paylaşım linki kopyalandı! 🔗'),
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                    child: const Icon(Icons.share_rounded, color: Colors.white70, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF56040)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Sosyal Medyada Bizi Takip Edin!',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Yeniliklerden haberdar olmak ve bizimle iletişime geçmek için resmi sosyal medya hesaplarımızı takip edin.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC13584), Color(0xFFE1306C)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Text('📸', style: TextStyle(fontSize: 14)),
              label: const Text('Instagram\'da Takip Et (@kiraclubsss)', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Text('🎵', style: TextStyle(fontSize: 14)),
              label: const Text('TikTok\'ta Takip Et (@kiraclubss)', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2937),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.borderCol),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'HAKKIMDA',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderCol),
          ),
          child: Text(
            user.bio != null && user.bio!.isNotEmpty ? user.bio! : 'Destek ekibi',
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSecretModeCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderCol),
      ),
      child: Row(
        children: [
          const Text('🕵️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Gizli Profil Modu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('GOLD/PLATINUM VIP', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Discover (Keşfet) sayfasında görünmez olursunuz. Ancak diğer profilleri gezebilir, mesajlaşabilir ve tüm özellikleri kullanabilirsiniz.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: _isSecretMode,
            activeColor: Colors.white,
            activeTrackColor: AppTheme.primaryColor,
            onChanged: (val) {
              if (user.isVip) {
                setState(() => _isSecretMode = val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Gizli Profil Modu sadece VIP üyeler içindir.'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderCol),
      ),
      child: Row(
        children: [
          const Text('🔔', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bildirimler Açık', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Mesaj ve arama bildirimlerini anında almak için bildirimleri açın.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.3)),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _notificationsOn = !_notificationsOn),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _notificationsOn ? const Color(0xFF064E3B) : const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(10),
                border: _notificationsOn ? null : Border.all(color: AppTheme.borderCol),
              ),
              child: Row(
                children: [
                  if (_notificationsOn) const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _notificationsOn ? 'Bildirimler Açık' : 'Kapalı', 
                    style: TextStyle(color: _notificationsOn ? const Color(0xFF10B981) : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(UserModel user) {
    final bool isVerified = user.verificationStatus == 'approved';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.check_rounded, color: AppTheme.textSecondary, size: 14),
              SizedBox(width: 4),
              Text(
                'Mavi Tik (Profil Doğrulama)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isVerified ? const Color(0xFF0F1E36) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isVerified ? const Color(0xFF1D4ED8) : AppTheme.borderCol),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isVerified ? const Color(0xFF3B82F6) : const Color(0xFF1F2937),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVerified ? 'Profiliniz Doğrulandı' : 'Doğrulanmamış Profil',
                      style: TextStyle(
                        color: isVerified ? const Color(0xFF60A5FA) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isVerified 
                          ? 'Tebrikler! Mavi Tik rozetiniz profilinizde aktif olarak gösterilmektedir.'
                          : 'Profilinizi doğrulayarak Mavi Tik sahibi olun.',
                      style: TextStyle(
                        color: isVerified ? const Color(0xFF93C5FD) : AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgencyButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1), // Purple-blue flat color matching Screenshot 4
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏢', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text(
              'Ajans Yönetim Panelene Git →',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderCol),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF2E1065),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.headphones_rounded, color: Color(0xFFC084FC), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Destek Taleplerim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Bir sorun mu yaşıyorsunuz? Destek ekibimize ulaşın.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(AuthProvider auth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF451A23), // Dark red background matching Screenshot 4
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.1)),
      ),
      child: ElevatedButton(
        onPressed: () => _logout(auth),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🚪', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text(
              'Çıkış',
              style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
