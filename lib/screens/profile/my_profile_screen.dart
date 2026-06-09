import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({Key? key}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final ApiService _api = ApiService();

  Future<void> _pickAvatar(UserModel user) async {
    final picker = ImagePicker();
    final img    = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    try {
      final url = await _api.uploadAvatar(img.path);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      auth.updateUser(user.copyWith(avatarUrl: url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf yüklenemedi.'),
            backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0A10),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.backgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(children: [
                // Cover gradient
                Container(
                  decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryColor.withOpacity(0.3), AppTheme.backgroundColor],
                  )),
                ),
                // Avatar
                Positioned(bottom: 24, left: 0, right: 0,
                  child: Column(children: [
                    GestureDetector(
                      onTap: () => _pickAvatar(user),
                      child: Stack(children: [
                        CircleAvatar(radius: 56, backgroundColor: AppTheme.cardColor,
                          backgroundImage: user.avatarUrl != null
                            ? CachedNetworkImageProvider(user.avatarUrl!) : null,
                          child: user.avatarUrl == null
                            ? Icon(Icons.person, color: AppTheme.textSecondary, size: 56) : null),
                        Positioned(bottom: 2, right: 2, child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(user.name, style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      if (user.verificationStatus == 'approved') ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: Color(0xFF3B82F6), size: 20),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(user.rankName, style: TextStyle(color: AppTheme.accentColor, fontSize: 14)),
                  ]),
                ),
              ]),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () {/* Edit profile screen */},
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () => _showSettings(context, auth),
              ),
            ],
          ),

          SliverToBoxAdapter(child: Column(children: [
            // Stats
            _statsRow(user),
            const SizedBox(height: 20),

            // VIP Card
            if (user.isVip) _vipCard(user),
            if (!user.isVip) _upgradeCard(),

            const SizedBox(height: 20),

            // Bio
            if (user.bio != null && user.bio!.isNotEmpty)
              _section('Hakkımda', child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(user.bio!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
              )),

            const SizedBox(height: 20),

            // Media grid
            if (user.media.isNotEmpty)
              _section('Fotoğraflarım', child: _mediaGrid(user.media)),

            const SizedBox(height: 100),
          ])),
        ],
      ),
    );
  }

  Widget _statsRow(UserModel user) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      _StatItem(label: 'Jeton', value: '${user.tokens}',
        icon: Icons.monetization_on_rounded, color: const Color(0xFFFFB800)),
      _divider(),
      _StatItem(label: 'Kazanç', value: '${user.earnedCoins}',
        icon: Icons.stars_rounded, color: AppTheme.accentColor),
      _divider(),
      _StatItem(label: 'Seviye', value: 'Lv.${user.level}',
        icon: Icons.emoji_events_rounded, color: AppTheme.primaryColor),
    ]),
  );

  Widget _divider() => Container(height: 40, width: 1, color: AppTheme.borderCol,
    margin: const EdgeInsets.symmetric(horizontal: 16));

  Widget _vipCard(UserModel user) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: AppTheme.primaryGradient,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3),
        blurRadius: 20, spreadRadius: 2)],
    ),
    child: Row(children: [
      const Icon(Icons.star_rounded, color: Colors.white, size: 32),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${user.vipLevel?.toUpperCase()} VIP',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text('Aktif üyelik', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
      ])),
      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
    ]),
  );

  Widget _upgradeCard() => GestureDetector(
    onTap: () {/* wallet screen */},
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderCol)),
      child: Row(children: [
        ShaderMask(
          shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 32)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('VIP\'e Yükselt', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Sınırsız özellikler açılsın', style: TextStyle(
            color: AppTheme.textSecondary, fontSize: 13)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
          child: const Text('Satın Al', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ]),
    ),
  );

  Widget _section(String title, {required Widget child}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 12),
      child,
    ],
  );

  Widget _mediaGrid(List<MediaItem> media) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
    itemCount: media.length,
    itemBuilder: (_, i) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(imageUrl: media[i].url, fit: BoxFit.cover)),
  );

  void _showSettings(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(context: context, backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppTheme.borderCol, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        ListTile(leading: const Icon(Icons.logout_rounded, color: Colors.red),
          title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
          onTap: () async {
            Navigator.pop(context);
            await auth.logout();
            if (mounted) Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label; final String value; final IconData icon; final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(icon, color: color, size: 22),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
  ]));
}
