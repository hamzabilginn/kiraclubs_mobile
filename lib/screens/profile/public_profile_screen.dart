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
  int  _currentPhoto = 0;

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
    _showToast('${_user!.name} beğenildi! 💜');
  }

  Future<void> _follow() async {
    if (_user == null) return;
    final following = await _api.followUser(_user!.id);
    setState(() => _isFollowing = following);
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AppTheme.primaryColor,
      behavior: SnackBarBehavior.floating));
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

  Widget _buildProfile(UserModel u) {
    // All photos: avatar + media
    final allPhotos = [
      if (u.avatarUrl != null) u.avatarUrl!,
      ...u.media.where((m) => m.type == 'photo').map((m) => m.url),
    ];

    return CustomScrollView(slivers: [
      // ── Photo Carousel AppBar ──────────────────────────────────────────────
      SliverAppBar(
        expandedHeight: 380, pinned: true,
        backgroundColor: AppTheme.backgroundColor,
        leading: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2))),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16)),
          onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5), shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2))),
              child: const Icon(Icons.more_horiz, color: Colors.white, size: 18)),
            onPressed: () => _showOptions()),
          const SizedBox(width: 8),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: Stack(children: [
            // Photo carousel
            allPhotos.isNotEmpty
              ? PageView.builder(
                  onPageChanged: (i) => setState(() => _currentPhoto = i),
                  itemCount: allPhotos.length,
                  itemBuilder: (_, i) => CachedNetworkImage(
                    imageUrl: allPhotos[i], fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: AppTheme.cardColor,
                      child: Center(child: Icon(Icons.person, color: AppTheme.textSecondary, size: 80)))))
              : Container(
                  decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryColor.withOpacity(0.4), AppTheme.backgroundColor])),
                  child: Center(child: Icon(Icons.person, color: AppTheme.textSecondary, size: 80))),

            // VIP glow border
            if (u.isVip) _vipBorderOverlay(u.vipLevel),

            // Bottom gradient
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                stops: const [0.45, 1.0])))),

            // Photo indicators
            if (allPhotos.length > 1)
              Positioned(top: 52, left: 0, right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(allPhotos.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPhoto == i ? 20 : 6, height: 4,
                    decoration: BoxDecoration(
                      color: _currentPhoto == i ? Colors.white : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2)))))),

            // User info overlay
            Positioned(bottom: 16, left: 20, right: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Text(u.name, style: const TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 10)]))),
                  if (u.verificationStatus == 'approved')
                    Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 16)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  if (u.isVip) _vipBadge(u.vipLevel),
                  if (u.isVip) const SizedBox(width: 8),
                  if (u.isOnline) _onlineBadge(),
                  if (u.agencyName != null) ...[
                    const SizedBox(width: 8),
                    _agencyBadge(u.agencyName!),
                  ],
                ]),
              ])),
          ]),
        ),
      ),

      SliverToBoxAdapter(child: Column(children: [
        // ── Social Stats ────────────────────────────────────────────────────
        _socialStats(u),

        const SizedBox(height: 16),

        // ── Action buttons ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _ActionBtn(
              label: _isFollowing ? 'Takiptesin' : 'Takip Et',
              icon: _isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
              onTap: _follow, isPrimary: !_isFollowing),
            const SizedBox(width: 10),
            _ActionBtn(
              label: 'Mesaj At',
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ChatScreen(partner: u)))),
            const SizedBox(width: 10),
            _ActionBtn(label: '', icon: Icons.favorite_rounded,
              onTap: _like, isPrimary: true, iconOnly: true),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Level & Rank ────────────────────────────────────────────────────
        _levelCard(u),

        const SizedBox(height: 20),

        // ── Bio ─────────────────────────────────────────────────────────────
        if (u.bio != null && u.bio!.isNotEmpty) ...[
          _sectionCard('Hakkında', child: Text(u.bio!,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6))),
          const SizedBox(height: 16),
        ],

        // ── Gift Showcase ───────────────────────────────────────────────────
        _giftShowcase(u.gifts),

        const SizedBox(height: 16),

        // ── Status Posts ─────────────────────────────────────────────────────
        if (u.statuses.isNotEmpty) ...[
          _statusSection(u.statuses),
          const SizedBox(height: 16),
        ],

        // ── Media Grid ───────────────────────────────────────────────────────
        if (u.media.isNotEmpty) ...[
          _sectionCard('Fotoğraflar', child: _mediaGrid(u.media)),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 100),
      ])),
    ]);
  }

  Widget _vipBorderOverlay(String? level) {
    final gradient = level == 'platinum'
      ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF3B82F6)])
      : level == 'gold'
        ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFEF08A), Color(0xFFD97706)])
        : const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFFCBD5E1)]);
    return Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
      border: Border.all(
        color: Colors.transparent, width: 3,
      ),
      gradient: gradient,
    )));
  }

  Widget _socialStats(UserModel u) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderCol)),
    child: Row(children: [
      _StatCell(value: '${u.followersCount}', label: 'Takipçi'),
      _vertDiv(),
      _StatCell(value: '${u.followingCount}', label: 'Takip'),
      _vertDiv(),
      _StatCell(value: '${u.totalLikes}', label: 'Beğeni'),
    ]),
  );

  Widget _vertDiv() => Container(width: 1, height: 40, color: AppTheme.borderCol,
    margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _levelCard(UserModel u) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderCol)),
    child: Row(children: [
      ShaderMask(
        shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
        child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(u.rankName, style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
        Text('Seviye ${u.level}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ])),
      SizedBox(width: 90, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${u.levelProgress}%', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: u.levelProgress / 100, minHeight: 6,
            backgroundColor: AppTheme.borderCol,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor))),
      ])),
    ]),
  );

  Widget _sectionCard(String title, {required Widget child}) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderCol)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      child,
    ]),
  );

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
        Text('Hediye Vitrini', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),
      gifts.isEmpty
        ? Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              const Text('💝', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text('Henüz hediye yok', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
    ]),
  );

  Widget _statusSection(List<StatusPost> statuses) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderCol)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Text('📣', style: TextStyle(fontSize: 16)),
        SizedBox(width: 6),
        Text('Paylaşımlar', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),
      ...statuses.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderCol)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.content, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 8),
          Row(children: [
            Text(_timeAgoFromDt(s.createdAt), style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            const Spacer(),
            GestureDetector(
              onTap: () {},
              child: Row(children: [
                Icon(s.isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  color: s.isLiked ? Colors.pink : AppTheme.textSecondary, size: 16),
                const SizedBox(width: 4),
                Text('${s.likesCount}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ])),
          ]),
        ]))),
    ]),
  );

  Widget _mediaGrid(List<MediaItem> media) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
    itemCount: media.length,
    itemBuilder: (_, i) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(imageUrl: media[i].url, fit: BoxFit.cover)));

  Widget _vipBadge(String? level) {
    final (String label, List<Color> colors, Color text) = level == 'platinum'
      ? ('💎 PLATINUM', [const Color(0xFF8B5CF6), const Color(0xFFEC4899)], Colors.white)
      : level == 'gold'
        ? ('👑 GOLD VIP', [const Color(0xFFF59E0B), const Color(0xFFD97706)], const Color(0xFF78350F))
        : ('🥈 SILVER', [const Color(0xFF94A3B8), const Color(0xFF64748B)], Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.w900)));
  }

  Widget _onlineBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(12)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, color: Colors.white, size: 8),
      SizedBox(width: 4),
      Text('Çevrimiçi', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    ]));

  Widget _agencyBadge(String name) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF10B981).withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('🏢', style: TextStyle(fontSize: 11)),
      const SizedBox(width: 4),
      Text(name, style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
    ]));

  void _showOptions() {
    showModalBottomSheet(
      context: context, backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppTheme.borderCol, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        ListTile(leading: const Icon(Icons.block_rounded, color: Colors.red),
          title: const Text('Engelle', style: TextStyle(color: Colors.red)),
          onTap: () async {
            Navigator.pop(context);
            if (_user != null) await _api.blockUser(_user!.id);
            if (mounted) Navigator.pop(context);
          }),
        ListTile(leading: Icon(Icons.flag_outlined, color: AppTheme.textSecondary),
          title: Text('Şikayet Et', style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () {
            Navigator.pop(context);
            if (_user != null) _api.reportUser(_user!.id, 'Uygunsuz içerik');
          }),
        const SizedBox(height: 16),
      ]));
  }

  String _timeAgoFromDt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Şimdi';
    if (d.inHours < 1) return '${d.inMinutes} dakika önce';
    if (d.inDays < 1) return '${d.inHours} saat önce';
    if (d.inDays < 7) return '${d.inDays} gün önce';
    return '${dt.day}/${dt.month}/${dt.year}';
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

class _ActionBtn extends StatelessWidget {
  final String label; final IconData icon;
  final VoidCallback onTap; final bool isPrimary; final bool iconOnly;

  const _ActionBtn({required this.label, required this.icon, required this.onTap,
    this.isPrimary = false, this.iconOnly = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      decoration: BoxDecoration(
        gradient: isPrimary ? AppTheme.primaryGradient : null,
        color: isPrimary ? null : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: isPrimary ? null : Border.all(color: AppTheme.borderCol),
        boxShadow: isPrimary ? [BoxShadow(
          color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 10, spreadRadius: 0)] : [],
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
