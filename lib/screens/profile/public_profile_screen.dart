import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../chat/chat_screen.dart';
import '../call/call_screen.dart';
import '../../widgets/autoplay_video_widget.dart';

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
  bool _isLoading = true;
  int _currentPhoto = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await _api.getUserById(widget.userId);
      setState(() {
        _user = res['user'] as UserModel;
        _isFollowing = res['is_following'] as bool? ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _like() async {
    if (_user == null) return;
    await _api.likeUser(_user!.id);
    _showToast('${_user!.name} beğenildi! 💜');
    _load(); // reload to update like count
  }

  Future<void> _follow() async {
    if (_user == null) return;
    final following = await _api.followUser(_user!.id);
    setState(() => _isFollowing = following);
    _load(); // reload to update follower count
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('Kullanıcı bulunamadı.', style: TextStyle(color: Colors.black54)))
              : _buildProfile(_user!),
      bottomNavigationBar: _user == null ? null : _buildBottomMenu(_user!),
    );
  }

  Widget _buildProfile(UserModel u) {
    final allMedia = [
      if (u.avatarUrl != null) MediaItem(id: -1, url: u.avatarUrl!, type: 'photo'),
      ...u.media,
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Photo Carousel AppBar
        SliverAppBar(
          expandedHeight: 400,
          pinned: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
              ),
              onPressed: () => _showOptions(),
            ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              children: [
                // Photo carousel
                allMedia.isNotEmpty
                    ? PageView.builder(
                        onPageChanged: (i) => setState(() => _currentPhoto = i),
                        itemCount: allMedia.length,
                        itemBuilder: (_, i) {
                          final item = allMedia[i];
                          return ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(32),
                              bottomRight: Radius.circular(32),
                            ),
                            child: item.type == 'video'
                                ? AutoplayVideoWidget(videoUrl: item.url, placeholderUrl: _user?.firstPhotoUrl)
                                : CachedNetworkImage(
                                    imageUrl: item.url,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorWidget: (_, __, ___) => Container(
                                      color: const Color(0xFFF1F5F9),
                                      child: const Center(child: Icon(Icons.person, color: Colors.black26, size: 80)),
                                    ),
                                  ),
                          );
                        },
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        child: const Center(child: Icon(Icons.person, color: Colors.white, size: 80)),
                      ),

                // Top shadow overlay for back/more buttons readability
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.35), Colors.transparent],
                      ),
                    ),
                  ),
                ),

                // VIP Border Overlay
                if (u.isVip) _buildVipBorderOverlay(u.vipLevel),

                // Media Heart Likes Overlay
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: GestureDetector(
                    onTap: _like,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('❤️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            '${u.totalLikes}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Photo indicator lines
                if (allMedia.length > 1)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        allMedia.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPhoto == i ? 18 : 6,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _currentPhoto == i ? Colors.white : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name & Badges Row
                Row(
                  children: [
                    const Text('✨ ☀️ ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        u.name,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (u.isVip) ...[
                      const SizedBox(width: 6),
                      _buildVipBadge(u.vipLevel),
                    ],
                    if (u.leaderboardRank != null) ...[
                      const SizedBox(width: 6),
                      _buildLeaderboardRankBadge(u.leaderboardRank),
                    ],
                    if (u.verificationStatus == 'verified' || u.verificationStatus == 'approved') ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Online/Offline Status Indicator
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: u.isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatLastSeen(u.lastSeenAt, u.isOnline),
                      style: TextStyle(
                        color: u.isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Follows & Likes stats (separated by thin vertical lines)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFF1F5F9)),
                      bottom: BorderSide(color: Color(0xFFF1F5F9)),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildStatCell('${u.followersCount}', 'TAKİPÇİ'),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                      _buildStatCell('${u.followingCount}', 'TAKİP EDİLEN'),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                      _buildStatCell('${u.totalLikes}', 'BEĞENİ'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // About Me Section
                const Text(
                  'HAKKIMDA',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Text(
                    u.bio != null && u.bio!.isNotEmpty ? u.bio! : 'Henüz bir biyografi eklemedi.',
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Gift Showcase Section
                const Row(
                  children: [
                    Text('🎁', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'HEDİYE VİTRİNİ',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildGiftGrid(u.gifts),
                const SizedBox(height: 24),

                // Status Posts Section
                if (u.statuses.isNotEmpty) ...[
                  const Row(
                    children: [
                      Text('📣', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text(
                        'PAYLAŞIMLAR',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildStatusList(u.statuses),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVipBorderOverlay(String? level) {
    final gradient = level == 'platinum'
        ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF3B82F6)])
        : level == 'gold'
            ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFEF08A), Color(0xFFD97706)])
            : const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFFCBD5E1)]);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          gradient: gradient,
        ),
      ),
    );
  }

  Widget _buildVipBadge(String? level) {
    final String label = level == 'platinum'
        ? '💎 PLATINUM'
        : level == 'gold'
            ? '👑 GOLD'
            : '🥈 SILVER';

    final gradient = level == 'platinum'
        ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)])
        : level == 'gold'
            ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
            : const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF64748B)]);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildLeaderboardRankBadge(int? rank) {
    if (rank == null) return const SizedBox.shrink();

    Gradient? grad;
    Color borderCol = Colors.transparent;
    String label = '';
    List<BoxShadow> shadow = [];

    if (rank <= 10) {
      label = '👑 #$rank';
      grad = const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF8B5CF6)]);
      borderCol = const Color(0xFFFBBF24).withOpacity(0.5);
      shadow = [
        BoxShadow(
          color: const Color(0xFFF59E0B).withOpacity(0.4),
          blurRadius: 10,
          spreadRadius: 1,
        )
      ];
    } else if (rank <= 50) {
      label = '🏆 #$rank';
      grad = const LinearGradient(colors: [Color(0xFF22D3EE), Color(0xFF2563EB)]);
      borderCol = const Color(0xFF22D3EE).withOpacity(0.3);
      shadow = [
        BoxShadow(
          color: const Color(0xFF22D3EE).withOpacity(0.2),
          blurRadius: 8,
        )
      ];
    } else if (rank <= 100) {
      label = '✨ #$rank';
      grad = const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]);
      borderCol = const Color(0xFF6366F1).withOpacity(0.2);
    } else {
      label = '#$rank';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: shadow,
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildStatCell(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid(List<GiftItem> gifts) {
    if (gifts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Column(
          children: [
            Text('💝', style: TextStyle(fontSize: 28)),
            SizedBox(height: 6),
            Text(
              'Henüz hediye gönderilmemiş.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: gifts.length,
        itemBuilder: (_, i) {
          final g = gifts[i];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: Center(
                  child: Text(g.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '${g.count}',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusList(List<StatusPost> statuses) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: statuses.length,
      itemBuilder: (_, i) {
        final s = statuses[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.content,
                style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _timeAgoFromDt(s.createdAt),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  Row(
                    children: [
                      Icon(
                        s.isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        color: s.isLiked ? Colors.redAccent : const Color(0xFF94A3B8),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${s.likesCount}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomMenu(UserModel u) {


    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Call Button (📞)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CallScreen(chatUser: u)),
              );
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDCFCE7),
                border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
              ),
              child: const Icon(Icons.phone, color: Color(0xFF22C55E), size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Follow / Following Button
          Expanded(
            child: GestureDetector(
              onTap: _follow,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: _isFollowing ? const Color(0xFFE2E8F0) : const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    _isFollowing ? 'Takip Edilen' : 'Takip Et',
                    style: TextStyle(
                      color: _isFollowing ? const Color(0xFF1E293B) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Gift Button (🎁)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(partner: u)),
              );
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFEF9C3),
                border: Border.all(color: const Color(0xFFFEF08A), width: 1.5),
              ),
              child: const Icon(Icons.card_giftcard, color: Color(0xFFEAB308), size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Chat Button (💬)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(partner: u)),
              );
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF472B6),
              ),
              child: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmBlock() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF161426),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text(
              'Kullanıcıyı Engelle',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Bu kullanıcıyı engellemek istediğinize emin misiniz? Engellenen kullanıcılar size mesaj gönderemez ve sizi arayamaz.',
          style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('İptal', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Engelle'),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (_user != null) {
                try {
                  await _api.blockUser(_user!.id);
                  _showToast('Kullanıcı başarıyla engellendi.');
                  if (mounted) Navigator.pop(context); // Close profile screen
                } catch (e) {
                  _showToast('Kullanıcı engellenemedi.');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final reasons = [
      'Spam veya Şüpheli Hesap',
      'Uygunsuz Fotoğraf / Video',
      'Çocuk İstismarı veya Sömürüsü (CSAE/CSAM)',
      'Taciz / Rahatsız Etme',
      'Sahte Profil / Başkası Gibi Davranma',
      'Diğer Nedenler'
    ];
    String selectedReason = reasons.first;
    final descCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161426),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.amber, size: 24),
              SizedBox(width: 10),
              Text(
                'Kullanıcıyı Şikayet Et',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Şikayet Nedeni',
                style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0D1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF161426),
                    value: selectedReason,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: reasons
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedReason = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Açıklama / Detaylar',
                style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0D1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Şikayetinizi detaylandırın...',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('İptal', style: TextStyle(color: Colors.white60)),
              onPressed: () => Navigator.pop(dialogCtx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        if (_user != null) {
                          await _api.reportUser(
                            _user!.id,
                            selectedReason,
                            description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                          );
                          _showToast('Şikayetiniz iletildi. Teşekkür ederiz.');
                        }
                        Navigator.pop(dialogCtx);
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        _showToast('Şikayet iletilemedi.');
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 8),
              ListTile(
                  leading: const Icon(Icons.block_rounded, color: Colors.red),
                  title: const Text('Engelle', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmBlock();
                  }),
              ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.black54),
                  title: const Text('Şikayet Et', style: TextStyle(color: Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog();
                  }),
              const SizedBox(height: 16),
            ],
          ),
    );
  }

  String _formatLastSeen(String? lastSeenIso, bool isOnline) {
    if (isOnline) return 'çevrimiçi';
    if (lastSeenIso == null) return 'çevrimdışı';
    try {
      final dt = DateTime.parse(lastSeenIso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 5) return 'çevrimiçi';
      if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
      if (diff.inHours < 24) return '${diff.inHours} sa önce';
      
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Bugün ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
        return 'Dün ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'çevrimdışı';
    }
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
