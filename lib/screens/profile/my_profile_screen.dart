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
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      auth.updateUser(user.copyWith(avatarUrl: url));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf yüklenemedi.'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    try {
      await _api.uploadMedia(img.path, 'photo');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fotoğraf yüklendi! ✅'),
          backgroundColor: Color(0xFF10B981), behavior: SnackBarBehavior.floating));
        // Reload user data
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final updated = await _api.getMe();
        auth.updateUser(updated);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf yüklenemedi.'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0A10),
        body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(slivers: [

        // ── Header SliverAppBar ──────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 300, pinned: true,
          backgroundColor: AppTheme.backgroundColor,
          actions: [
            IconButton(
              icon: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4), shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2))),
                child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18)),
              onPressed: () {},
            ),
            IconButton(
              icon: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4), shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2))),
                child: const Icon(Icons.settings_outlined, color: Colors.white, size: 18)),
              onPressed: () => _showSettings(context, auth),
            ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(children: [
              // Background gradient
              Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppTheme.primaryColor.withOpacity(0.35), AppTheme.backgroundColor]))),

              // VIP glow ring behind avatar
              if (user.isVip)
                Center(child: Transform.translate(
                  offset: const Offset(0, 30),
                  child: Container(
                    width: 130, height: 130, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _vipGradient(user.vipLevel),
                    )))),

              // Avatar
              Positioned(bottom: 60, left: 0, right: 0,
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
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(user.name, style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    if (user.verificationStatus == 'approved') ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14)),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  if (user.isVip)
                    _vipTag(user.vipLevel)
                  else
                    Text(user.rankName, style: TextStyle(color: AppTheme.accentColor, fontSize: 14)),
                ]),
              ),
            ]),
          ),
        ),

        SliverToBoxAdapter(child: Column(children: [
          // ── Social Stats ─────────────────────────────────────────────────
          _socialStats(user),
          const SizedBox(height: 20),

          // ── Quick Stats Row ──────────────────────────────────────────────
          _quickStatsRow(user),
          const SizedBox(height: 20),

          // ── VIP Card or Upgrade ──────────────────────────────────────────
          if (user.isVip) _vipCard(user) else _upgradeCard(),
          const SizedBox(height: 20),

          // ── Bio ──────────────────────────────────────────────────────────
          if (user.bio != null && user.bio!.isNotEmpty)
            _infoCard('Hakkımda', child: Text(user.bio!,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6))),
          if (user.bio != null && user.bio!.isNotEmpty) const SizedBox(height: 16),

          // ── Gift Showcase ────────────────────────────────────────────────
          _giftShowcase(user.gifts),
          const SizedBox(height: 16),

          // ── My Photos ───────────────────────────────────────────────────
          _infoCard('Fotoğraflarım', trailing: GestureDetector(
            onTap: _pickMedia,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Ekle', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ]))),
            child: user.media.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(children: [
                    Icon(Icons.photo_library_outlined, size: 40, color: AppTheme.textSecondary),
                    const SizedBox(height: 8),
                    Text('Fotoğraf ekle', style: TextStyle(color: AppTheme.textSecondary)),
                  ])))
              : GridView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                  itemCount: user.media.length,
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(imageUrl: user.media[i].url, fit: BoxFit.cover)))),
          const SizedBox(height: 100),
        ])),
      ]),
    );
  }

  Widget _socialStats(UserModel user) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderCol)),
    child: Row(children: [
      _StatCell(value: '${user.followersCount}', label: 'Takipçi'),
      _divider(),
      _StatCell(value: '${user.followingCount}', label: 'Takip'),
      _divider(),
      _StatCell(value: '${user.totalLikes}', label: 'Beğeni'),
    ]),
  );

  Widget _divider() => Container(height: 40, width: 1, color: AppTheme.borderCol,
    margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _quickStatsRow(UserModel user) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      _QuickStat(icon: Icons.monetization_on_rounded,
        value: '${user.tokens}', label: 'Jeton', color: const Color(0xFFFFB800)),
      const SizedBox(width: 10),
      _QuickStat(icon: Icons.stars_rounded,
        value: '${user.earnedCoins}', label: 'Kazanç', color: AppTheme.accentColor),
      const SizedBox(width: 10),
      _QuickStat(icon: Icons.emoji_events_rounded,
        value: 'Lv.${user.level}', label: 'Seviye', color: AppTheme.primaryColor),
    ]),
  );

  Widget _vipCard(UserModel user) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: _vipGradient(user.vipLevel),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 20)]),
    child: Row(children: [
      const Icon(Icons.star_rounded, color: Colors.white, size: 32),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${user.vipLevel?.toUpperCase()} VIP',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text('Aktif üyelik', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)),
      ])),
      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
    ]));

  Widget _upgradeCard() => GestureDetector(
    onTap: () {},
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
          Text('VIP\'e Yükselt', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Sınırsız özellikler açılsın', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
          child: const Text('Satın Al', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ])));

  Widget _infoCard(String title, {required Widget child, Widget? trailing}) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderCol)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (trailing != null) trailing,
      ]),
      const SizedBox(height: 12),
      child,
    ]));

  Widget _giftShowcase(List<GiftItem> gifts) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderCol)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Text('🎁', style: TextStyle(fontSize: 16)),
        SizedBox(width: 6),
        Text('Hediye Vitrini', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),
      gifts.isEmpty
        ? Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              const Text('💝', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text('Henüz hediye almadın', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ])))
        : GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
            itemCount: gifts.length,
            itemBuilder: (_, i) {
              final g = gifts[i];
              return Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderCol)),
                  child: Center(child: Text(g.emoji, style: const TextStyle(fontSize: 28)))),
                Positioned(top: -2, right: -2, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.backgroundColor, width: 1.5)),
                  child: Text('${g.count}', style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)))),
              ]);
            }),
    ]));

  Widget _vipTag(String? level) {
    if (level == null) return const SizedBox.shrink();
    final (String label, List<Color> colors, Color text) = level == 'platinum'
      ? ('💎 PLATINUM', [const Color(0xFF8B5CF6), const Color(0xFFEC4899)], Colors.white)
      : level == 'gold'
        ? ('👑 GOLD VIP', [const Color(0xFFF59E0B), const Color(0xFFD97706)], const Color(0xFF78350F))
        : ('🥈 SILVER', [const Color(0xFF94A3B8), const Color(0xFF64748B)], Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors.first.withOpacity(0.4), blurRadius: 12)]),
      child: Text(label, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w900)));
  }

  LinearGradient _vipGradient(String? level) {
    if (level == 'platinum') return const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF3B82F6)]);
    if (level == 'gold') return const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]);
    return const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF64748B)]);
  }

  void _showSettings(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context, backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppTheme.borderCol, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: Colors.red),
          title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
          onTap: () async {
            Navigator.pop(context);
            await auth.logout();
            if (mounted) Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }),
        const SizedBox(height: 16),
      ]));
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
  ]));
}

class _QuickStat extends StatelessWidget {
  final IconData icon; final String value; final String label; final Color color;
  const _QuickStat({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.borderCol)),
    child: Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
    ])));
}
