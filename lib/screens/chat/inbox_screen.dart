import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'chat_screen.dart';
import '../profile/public_profile_screen.dart';
import '../profile/likers_screen.dart';
import '../profile/visitors_screen.dart';
import '../call/call_screen.dart';


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
  List<int> _pinnedUserIds = [];

  // Calls
  List<CallLogItem> _calls = [];

  // Likers (beğenenler)
  List<Map<String, dynamic>> _likers = [];
  bool _loadingLikers = true;

  // Visitors (ziyaretçiler)
  List<Map<String, dynamic>> _visitors = [];
  bool _loadingVisitors = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      switch (_tabController.index) {
        case 0: _loadMessages(); break;
        case 1: _loadMessages(); break;
        case 2: _loadLikers(); break;
        case 3: _loadVisitors(); break;
      }
    });
    _loadPinnedUserIds();
    _loadMessages();
  }

  Future<void> _loadPinnedUserIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('pinned_conversations') ?? [];
      setState(() {
        _pinnedUserIds = list.map((id) => int.parse(id)).toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loadingMessages = true);
    try {
      final data = await _api.getInbox();
      if (mounted) {
        setState(() {
          _conversations = data['conversations'] as List<ConversationModel>;
          _calls = data['calls'] as List<CallLogItem>;
          _loadingMessages = false;
        });
      }
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

  void _showMassMessageDialog() {
    final TextEditingController msgCtrl = TextEditingController();
    bool isSendingMass = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161426),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.campaign_rounded, color: Color(0xFFEC4899), size: 24),
              SizedBox(width: 10),
              Text(
                'Toplu Mesaj Gönder',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yazacağınız mesaj sistemdeki tüm erkek üyelere toplu olarak gönderilecektir.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0D1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: msgCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Mesajınızı yazın...',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
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
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSendingMass
                  ? null
                  : () async {
                      final txt = msgCtrl.text.trim();
                      if (txt.isEmpty) return;

                      setDialogState(() => isSendingMass = true);
                      try {
                        final res = await _api.sendMassMessage(txt);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(res['message'] ?? 'Toplu mesaj başarıyla gönderildi!'),
                            backgroundColor: Colors.green,
                          ));
                        }
                        Navigator.pop(dialogCtx);
                      } catch (e) {
                        setDialogState(() => isSendingMass = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: Colors.red,
                          ));
                        }
                      }
                    },
              child: isSendingMass
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(child: Column(children: [
        _header(currentUser),
        _tabBar(),
        Expanded(child: TabBarView(
          controller: _tabController,
          children: [
            _messagesTab(),
            _callsTab(),
            _likersTab(),
            _visitorsTab(),
          ],
        )),
      ])),
    );
  }

  Widget _header(UserModel? currentUser) {
    final bool isFemale = currentUser?.gender == 'female';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        const Text('Aktivite',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (isFemale) ...[
          GestureDetector(
            onTap: _showMassMessageDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.campaign_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Toplu Mesaj',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
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
  }

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
        Tab(icon: Icon(Icons.call_outlined, size: 16), text: 'Aramalar'),
        Tab(icon: Icon(Icons.favorite_outline_rounded, size: 16), text: 'Beğenenler'),
        Tab(icon: Icon(Icons.remove_red_eye_outlined, size: 16), text: 'Ziyaretçiler'),
      ],
    ),
  );

  // ─── Messages Tab ───────────────────────────────────────────────────────────

  Widget _messagesTab() {
    if (_loadingMessages) return _shimmerList();
    if (_conversations.isEmpty) {
      return _empty('Henüz mesajın yok', "Keşfet'ten birileriyle tanış! 💜", Icons.chat_bubble_outline_rounded);
    }

    final sortedConversations = List<ConversationModel>.from(_conversations);
    sortedConversations.sort((a, b) {
      final aPinned = _pinnedUserIds.contains(a.partner.id);
      final bPinned = _pinnedUserIds.contains(b.partner.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });

    return RefreshIndicator(
        onRefresh: _loadMessages,
        color: AppTheme.primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          itemCount: sortedConversations.length,
          itemBuilder: (_, i) => _conversationTile(sortedConversations[i])));
  }

  void _showConversationOptions(ConversationModel conv) {
    final bool isPinned = _pinnedUserIds.contains(conv.partner.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0D1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: isPinned ? Colors.amber : Colors.white60,
              ),
              title: Text(
                isPinned ? 'Sohbetin Sabitlemesini Kaldır' : 'Sohbeti Sabitle',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                setState(() {
                  if (isPinned) {
                    _pinnedUserIds.remove(conv.partner.id);
                  } else {
                    _pinnedUserIds.add(conv.partner.id);
                  }
                });
                await prefs.setStringList(
                  'pinned_conversations',
                  _pinnedUserIds.map((id) => id.toString()).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationTile(ConversationModel conv) {
    final p = conv.partner;
    final m = conv.lastMessage;
    final hasUnread = conv.unreadCount > 0;
    final isPinned = _pinnedUserIds.contains(p.id);

    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(partner: p))).then((_) => _loadMessages()),
      onLongPress: () => _showConversationOptions(conv),
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
              Expanded(child: Row(
                children: [
                  Flexible(
                    child: Text(p.name, 
                      style: TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal),
                      overflow: TextOverflow.ellipsis),
                  ),
                  if (isPinned) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.push_pin_rounded, color: Colors.amber, size: 14),
                  ]
                ],
              )),
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
              : (sender?.avatarUrl != null && sender!.avatarUrl!.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: sender!.avatarUrl!,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      errorWidget: (context, url, error) => Center(child: Icon(Icons.person, color: AppTheme.textSecondary, size: 28)),
                    )
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
              : (viewer?.avatarUrl != null && viewer!.avatarUrl!.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: viewer!.avatarUrl!,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      errorWidget: (context, url, error) => Center(child: Icon(Icons.person, color: AppTheme.textSecondary, size: 28)),
                    )
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

  Widget _avatar(String? url, double radius) {
    final bool isVideo = url != null &&
        (url.toLowerCase().endsWith('.mov') ||
            url.toLowerCase().endsWith('.mp4') ||
            url.toLowerCase().endsWith('.avi') ||
            url.toLowerCase().endsWith('.mkv') ||
            url.toLowerCase().endsWith('.webm'));
    final bool hasValidImage = url != null && url.trim().isNotEmpty && !isVideo;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.cardColor,
      backgroundImage: hasValidImage ? CachedNetworkImageProvider(url) : null,
      child: !hasValidImage ? Icon(Icons.person, color: AppTheme.textSecondary) : null,
    );
  }

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

  Widget _callsTab() => _loadingMessages
    ? _shimmerList()
    : _calls.isEmpty
      ? _empty('Henüz araman yok', 'Geçmiş aramaların burada listelenir. 📞', Icons.call_outlined)
      : RefreshIndicator(
          onRefresh: _loadMessages,
          color: AppTheme.primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            itemCount: _calls.length,
            itemBuilder: (_, i) => _callTile(_calls[i])));

  Widget _callTile(CallLogItem call) {
    final otherUser = call.user;
    final isOutgoing = call.direction == 'outgoing';
    final isMissed = call.type == 'call_missed';

    final minutes = call.duration ~/ 60;
    final seconds = call.duration % 60;
    final durationStr = call.duration > 0
        ? '${minutes}:${seconds.toString().padLeft(2, '0')}'
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderCol),
      ),
      child: Row(children: [
        Stack(children: [
          _avatar(otherUser.avatarUrl, 28),
          if (otherUser.isOnline)
            Positioned(bottom: 2, right: 2, child: Container(
              width: 12, height: 12, decoration: BoxDecoration(
                color: const Color(0xFF10B981), shape: BoxShape.circle,
                border: Border.all(color: AppTheme.backgroundColor, width: 2)))),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(otherUser.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
            if (otherUser.isVip)
              _vipBadge(otherUser.vipLevel),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(
              isOutgoing ? Icons.call_made_rounded : (isMissed ? Icons.call_missed_rounded : Icons.call_received_rounded),
              size: 14,
              color: isOutgoing ? Colors.blue : (isMissed ? Colors.red : Colors.green),
            ),
            const SizedBox(width: 4),
            Text(
              isOutgoing
                  ? 'Giden Arama'
                  : (isMissed ? 'Cevapsız Arama' : 'Gelen Arama'),
              style: TextStyle(
                color: isMissed ? Colors.red : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isMissed ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (durationStr != null) ...[
              const SizedBox(width: 6),
              Text('($durationStr)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ]),
          const SizedBox(height: 2),
          Text('⏱ ${_timeAgo(call.createdAt)}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ])),
        const SizedBox(width: 12),
        _callbackBtn(() {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(chatUser: otherUser)));
        }),
      ]),
    );
  }

  Widget _callbackBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 8)]),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.phone_enabled_rounded, color: Colors.white, size: 12),
        SizedBox(width: 4),
        Text('Geri Ara', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ])));

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
