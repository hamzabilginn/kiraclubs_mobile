import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import 'chat_screen.dart';
import '../profile/public_profile_screen.dart';
import '../profile/likers_screen.dart';
import '../profile/visitors_screen.dart';


class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  // Messages
  List<ConversationModel> _conversations = [];
  bool _loadingMessages = true;

  // Likers (beğenenler)
  List<Map<String, dynamic>> _likers = [];
  bool _loadingLikers = true;

  // Visitors (ziyaretçiler)
  List<Map<String, dynamic>> _visitors = [];
  bool _loadingVisitors = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      switch (_tabController.index) {
        case 0: _loadMessages(); break;
        case 1: _loadLikers(); break;
        case 2: _loadVisitors(); break;
      }
    });
    _loadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loadingMessages = true);
    try {
      final convs = await _api.getInbox();
      if (mounted) setState(() { _conversations = convs; _loadingMessages = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  Future<void> _loadLikers() async {
    setState(() => _loadingLikers = true);
    try {
      final data = await _api.getLikers();
      if (mounted) setState(() { _likers = data; _loadingLikers = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLikers = false);
    }
  }

  Future<void> _loadVisitors() async {
    setState(() => _loadingVisitors = true);
    try {
      final data = await _api.getVisitors();
      if (mounted) setState(() { _visitors = data; _loadingVisitors = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingVisitors = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    body: SafeArea(child: Column(children: [
      _header(),
      _tabBar(),
      Expanded(child: TabBarView(
        controller: _tabController,
        children: [
          _messagesTab(),
          _likersTab(),
          _visitorsTab(),
        ],
      )),
    ])),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(children: [
      const Text('Aktivite',
        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      const Spacer(),
      Container(
        decoration: BoxDecoration(color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderCol)),
        child: IconButton(
          icon: Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
          onPressed: () {},
        ),
      ),
    ]),
  );

  Widget _tabBar() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.cardColor, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.borderCol)),
    child: TabBar(
      controller: _tabController,
      indicator: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.white,
      unselectedLabelColor: AppTheme.textSecondary,
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      padding: const EdgeInsets.all(4),
      tabs: const [
        Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 16), text: 'Mesajlar'),
        Tab(icon: Icon(Icons.favorite_outline_rounded, size: 16), text: 'Beğenenler'),
        Tab(icon: Icon(Icons.remove_red_eye_outlined, size: 16), text: 'Ziyaretçiler'),
      ],
    ),
  );

  // ─── Messages Tab ───────────────────────────────────────────────────────────

  Widget _messagesTab() => _loadingMessages
    ? _shimmerList()
    : _conversations.isEmpty
      ? _empty('Henüz mesajın yok', "Keşfet'ten birileriyle tanış! 💜", Icons.chat_bubble_outline_rounded)
      : RefreshIndicator(
          onRefresh: _loadMessages,
          color: AppTheme.primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            itemCount: _conversations.length,
            itemBuilder: (_, i) => _conversationTile(_conversations[i])));

  Widget _conversationTile(ConversationModel conv) {
    final p = conv.partner;
    final m = conv.lastMessage;
    final hasUnread = conv.unreadCount > 0;
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(partner: p))).then((_) => _loadMessages()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread ? AppTheme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: hasUnread ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3)) : null,
        ),
        child: Row(children: [
          Stack(children: [
            _avatar(p.avatarUrl, 28),
            if (p.isOnline) Positioned(bottom: 2, right: 2, child: Container(
              width: 12, height: 12, decoration: BoxDecoration(
                color: const Color(0xFF10B981), shape: BoxShape.circle,
                border: Border.all(color: AppTheme.backgroundColor, width: 2)))),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(p.name, style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal))),
              if (m != null) Text(_timeAgo(m.createdAt), style: TextStyle(
                color: hasUnread ? AppTheme.primaryColor : AppTheme.textSecondary, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              if (m?.isMine == true) ...[
                Icon(Icons.done_all_rounded, size: 14,
                  color: m!.isRead ? AppTheme.primaryColor : AppTheme.textSecondary),
                const SizedBox(width: 4),
              ],
              Expanded(child: Text(
                m?.type == 'image' ? '📷 Fotoğraf'
                  : m?.type == 'voice' ? '🎵 Sesli mesaj'
                  : m?.body ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: hasUnread ? Colors.white70 : AppTheme.textSecondary, fontSize: 13))),
              if (hasUnread) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: Text('${conv.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            ]),
          ])),
        ]),
      ),
    );
  }

  // ─── Likers Tab ─────────────────────────────────────────────────────────────

  Widget _likersTab() => _loadingLikers
    ? _shimmerList()
    : _likers.isEmpty
      ? _empty('Henüz beğenin yok', 'Profilini tamamla ve keşfedilmeyi bekle! 💜', Icons.favorite_outline_rounded)
      : RefreshIndicator(
          onRefresh: _loadLikers,
          color: AppTheme.primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            itemCount: _likers.length,
            itemBuilder: (_, i) => _likerTile(_likers[i])));

  Widget _likerTile(Map<String, dynamic> like) {
    final sender = like['sender'] as UserModel?;
    final isLocked = like['is_locked'] as bool? ?? false;
    final targetLabel = like['target_label'] as String? ?? 'Beğendi';
    final createdAt = like['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCol)),
      child: Row(children: [
        Stack(children: [
          ClipOval(child: Container(
            width: 56, height: 56, color: AppTheme.cardColor,
            child: isLocked
              ? const ColoredBox(color: Color(0xFF1A1830),
                  child: Center(child: Text('🔒', style: TextStyle(fontSize: 24))))
              : (sender?.avatarUrl != null
                  ? CachedNetworkImage(imageUrl: sender!.avatarUrl!, fit: BoxFit.cover, width: 56, height: 56)
                  : Center(child: Icon(Icons.person, color: AppTheme.textSecondary, size: 28))),
          )),
          if (sender?.isVip == true && !isLocked)
            Positioned(bottom: 0, right: 0, child: _vipDot(sender!.vipLevel)),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(
              isLocked ? 'Gizli Üye' : (sender?.name ?? '?'),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
            if (sender != null && !isLocked)
              _vipBadge(sender.vipLevel),
          ]),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3))),
            child: Text(targetLabel, style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold))),
          if (createdAt != null) ...[
            const SizedBox(height: 2),
            Text('⏱ ${_timeAgoStr(createdAt)}',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ])),
        const SizedBox(width: 12),
        if (isLocked)
          _lockBtn(() => _unlockLiker(like))
        else if (sender != null)
          _chatBtn(() => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ChatScreen(partner: sender)))),
      ]),
    );
  }

  // ─── Visitors Tab ────────────────────────────────────────────────────────────

  Widget _visitorsTab() => _loadingVisitors
    ? _shimmerList()
    : _visitors.isEmpty
      ? _empty('Henüz ziyaretçin yok', 'Keşfet\'te yer aldığında göreceksin! 👀', Icons.remove_red_eye_outlined)
      : RefreshIndicator(
          onRefresh: _loadVisitors,
          color: AppTheme.primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            itemCount: _visitors.length,
            itemBuilder: (_, i) => _visitorTile(_visitors[i])));

  Widget _visitorTile(Map<String, dynamic> visit) {
    final viewer = visit['viewer'] as UserModel?;
    final isLocked = visit['is_locked'] as bool? ?? false;
    final updatedAt = visit['updated_at'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCol)),
      child: Row(children: [
        Stack(children: [
          ClipOval(child: Container(
            width: 56, height: 56, color: const Color(0xFF1A1830),
            child: isLocked
              ? const Center(child: Text('🔒', style: TextStyle(fontSize: 24)))
              : (viewer?.avatarUrl != null
                  ? CachedNetworkImage(imageUrl: viewer!.avatarUrl!, fit: BoxFit.cover, width: 56, height: 56)
                  : Center(child: Icon(Icons.person, color: AppTheme.textSecondary, size: 28))),
          )),
          if (viewer?.isVip == true && !isLocked)
            Positioned(bottom: 0, right: 0, child: _vipDot(viewer!.vipLevel)),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(
              isLocked ? 'Gizli Üye' : (viewer?.name ?? '?'),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
            if (viewer != null && !isLocked)
              _vipBadge(viewer.vipLevel),
          ]),
          const SizedBox(height: 4),
          Text(
            isLocked ? 'Profilini kimin ziyaret ettiğini görmek için kilidi aç' : (viewer?.bio ?? ''),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          if (updatedAt != null) ...[
            const SizedBox(height: 2),
            Text('⏱ ${_timeAgoStr(updatedAt)} ziyaret etti',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ])),
        const SizedBox(width: 12),
        if (isLocked)
          _lockBtn(() => _unlockVisitor(visit))
        else if (viewer != null)
          _viewProfileBtn(() => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: viewer.id)))),
      ]),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _avatar(String? url, double radius) => CircleAvatar(
    radius: radius, backgroundColor: AppTheme.cardColor,
    backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
    child: url == null ? Icon(Icons.person, color: AppTheme.textSecondary) : null,
  );

  Widget _vipDot(String? level) {
    final Color c = level == 'platinum' ? const Color(0xFF8B5CF6)
      : level == 'gold' ? const Color(0xFFF59E0B)
      : const Color(0xFF94A3B8);
    return Container(
      width: 16, height: 16,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle,
        border: Border.all(color: AppTheme.backgroundColor, width: 2)),
      child: const Center(child: Text('⭐', style: TextStyle(fontSize: 7))),
    );
  }

  Widget _vipBadge(String? level) {
    if (level == null) return const SizedBox.shrink();
    final (String label, Color bg, Color text) = level == 'platinum'
      ? ('💎 PLAT', const Color(0xFF4C1D95), Colors.white)
      : level == 'gold'
        ? ('👑 GOLD', const Color(0xFF78350F), const Color(0xFFFBBF24))
        : ('🥈 SİLVER', const Color(0xFF1E293B), const Color(0xFF94A3B8));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: text, fontSize: 9, fontWeight: FontWeight.w900)));
  }

  Widget _lockBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 8)]),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Text('🔒', style: TextStyle(fontSize: 12)),
        SizedBox(width: 4),
        Text('10 Kredi', style: TextStyle(color: Color(0xFF78350F), fontSize: 10, fontWeight: FontWeight.w900)),
      ])));

  Widget _chatBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEC4899), borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.3), blurRadius: 8)]),
      child: const Text('Mesaj At', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))));

  Widget _viewProfileBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8)]),
      child: const Text('Profil', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))));

  Widget _shimmerList() => Shimmer.fromColors(
    baseColor: AppTheme.cardColor, highlightColor: const Color(0xFF2A2740),
    child: ListView.builder(itemCount: 8, itemBuilder: (_, __) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), height: 72,
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)))));

  Widget _empty(String title, String subtitle, IconData icon) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 64, color: AppTheme.textSecondary),
      const SizedBox(height: 16),
      Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(subtitle, textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
    ]));

  void _unlockLiker(Map<String, dynamic> like) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LikersScreen()),
    ).then((_) {
      _loadLikers();
    });
  }

  void _unlockVisitor(Map<String, dynamic> visit) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VisitorsScreen()),
    ).then((_) {
      _loadVisitors();
    });
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Şimdi';
    if (d.inHours < 1) return '${d.inMinutes}dk';
    if (d.inDays < 1) return '${d.inHours}s';
    if (d.inDays < 7) return '${d.inDays}g';
    return '${dt.day}/${dt.month}';
  }

  String _timeAgoStr(String iso) {
    try { return _timeAgo(DateTime.parse(iso)); } catch (_) { return ''; }
  }
}
