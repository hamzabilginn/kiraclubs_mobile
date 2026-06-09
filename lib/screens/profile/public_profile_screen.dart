import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../chat/chat_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final int userId;
  const PublicProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final ApiService _api = ApiService();
  UserModel? _user;
  bool _isFollowing = false;
  bool _isLoading   = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final user = await _api.getUserById(widget.userId);
      setState(() { _user = user; _isLoading = false; });
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _like() async {
    if (_user == null) return;
    await _api.likeUser(_user!.id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_user!.name} beğenildi! 💜'),
      backgroundColor: AppTheme.primaryColor, behavior: SnackBarBehavior.floating));
  }

  Future<void> _follow() async {
    if (_user == null) return;
    final following = await _api.followUser(_user!.id);
    setState(() => _isFollowing = following);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    body: _isLoading
      ? const Center(child: CircularProgressIndicator())
      : _user == null
        ? Center(child: Text('Kullanıcı bulunamadı.', style: TextStyle(color: AppTheme.textSecondary)))
        : _buildProfile(_user!),
  );

  Widget _buildProfile(UserModel u) => CustomScrollView(slivers: [
    SliverAppBar(
      expandedHeight: 320, pinned: true,
      backgroundColor: AppTheme.backgroundColor,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context)),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(children: [
          // Photo
          Positioned.fill(child: u.avatarUrl != null
            ? CachedNetworkImage(imageUrl: u.avatarUrl!, fit: BoxFit.cover)
            : Container(color: AppTheme.cardColor)),
          // Gradient
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
              stops: const [0.4, 1.0])))),
          // Info
          Positioned(bottom: 20, left: 20, right: 20, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(u.name, style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
                if (u.verificationStatus == 'approved')
                  const Icon(Icons.verified_rounded, color: Color(0xFF3B82F6), size: 24),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                if (u.isVip) _vipBadge(u),
                if (u.isVip) const SizedBox(width: 8),
                if (u.isOnline) _onlineBadge(),
              ]),
            ],
          )),
        ]),
      ),
    ),

    SliverToBoxAdapter(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Action buttons
        Row(children: [
          Expanded(child: _ActionBtn(
            label: _isFollowing ? 'Takiptesin' : 'Takip Et',
            icon: _isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
            onTap: _follow,
            isPrimary: !_isFollowing,
          )),
          const SizedBox(width: 12),
          Expanded(child: _ActionBtn(
            label: 'Mesaj At',
            icon: Icons.chat_bubble_outline_rounded,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ChatScreen(partner: u))),
          )),
          const SizedBox(width: 12),
          _ActionBtn(
            label: '', icon: Icons.favorite_rounded,
            onTap: _like, isPrimary: true, iconOnly: true,
          ),
        ]),

        const SizedBox(height: 24),

        // Rank & level
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderCol)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.rankName, style: TextStyle(color: AppTheme.primaryColor,
                fontSize: 14, fontWeight: FontWeight.bold)),
              Text('Seviye ${u.level}', style: const TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Spacer(),
            // Level progress bar
            SizedBox(width: 100, child: Column(
              crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${u.levelProgress}%', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: u.levelProgress / 100, minHeight: 6,
                  backgroundColor: AppTheme.borderCol,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                )),
            ])),
          ]),
        ),

        const SizedBox(height: 20),

        // Bio
        if (u.bio != null && u.bio!.isNotEmpty) ...[
          const Text('Hakkında', style: TextStyle(color: Colors.white,
            fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(u.bio!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 20),
        ],

        // Media
        if (u.media.isNotEmpty) ...[
          const Text('Fotoğraflar', style: TextStyle(color: Colors.white,
            fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
            itemCount: u.media.length,
            itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(imageUrl: u.media[i].url, fit: BoxFit.cover))),
        ],
      ]),
    )),
  ]);

  Widget _vipBadge(UserModel u) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, color: Colors.white, size: 12),
      const SizedBox(width: 4),
      Text(u.vipLevel?.toUpperCase() ?? 'VIP',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    ]));

  Widget _onlineBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(12)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, color: Colors.white, size: 8),
      SizedBox(width: 4),
      Text('Çevrimiçi', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    ]));
}

class _ActionBtn extends StatelessWidget {
  final String label; final IconData icon;
  final VoidCallback onTap; final bool isPrimary; final bool iconOnly;

  const _ActionBtn({required this.label, required this.icon, required this.onTap,
    this.isPrimary = false, this.iconOnly = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: isPrimary ? AppTheme.primaryGradient : null,
        color: isPrimary ? null : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: isPrimary ? null : Border.all(color: AppTheme.borderCol),
      ),
      child: Center(child: iconOnly
        ? Icon(icon, color: Colors.white, size: 20)
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: isPrimary ? Colors.white : AppTheme.textSecondary, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isPrimary ? Colors.white : AppTheme.textSecondary,
              fontSize: 14, fontWeight: FontWeight.w600)),
          ])),
    ),
  );
}
