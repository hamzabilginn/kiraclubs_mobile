import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../../models/message_model.dart';
import '../../services/api_service.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final ApiService _api = ApiService();
  List<ConversationModel> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final convs = await _api.getInbox();
      setState(() { _conversations = convs; _isLoading = false; });
    } catch (e) { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    body: SafeArea(child: Column(children: [
      _header(),
      Expanded(child: _isLoading ? _shimmerList()
          : _conversations.isEmpty ? _empty()
          : RefreshIndicator(onRefresh: _load, color: AppTheme.primaryColor,
              child: ListView.builder(itemCount: _conversations.length,
                itemBuilder: (_, i) => _tile(_conversations[i])))),
    ])),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    child: Row(children: [
      const Text('Mesajlar', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      const Spacer(),
      Container(
        decoration: BoxDecoration(color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderCol)),
        child: IconButton(icon: Icon(Icons.edit_outlined, color: AppTheme.textSecondary), onPressed: () {}),
      ),
    ]),
  );

  Widget _tile(ConversationModel conv) {
    final p = conv.partner;
    final m = conv.lastMessage;
    final hasUnread = conv.unreadCount > 0;
    return GestureDetector(
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(partner: p))).then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread ? AppTheme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: hasUnread ? Border.all(color: AppTheme.borderCol, width: 0.5) : null,
        ),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(radius: 28, backgroundColor: AppTheme.cardColor,
              backgroundImage: p.avatarUrl != null ? CachedNetworkImageProvider(p.avatarUrl!) : null,
              child: p.avatarUrl == null ? Icon(Icons.person, color: AppTheme.textSecondary) : null),
            if (p.isOnline) Positioned(bottom: 2, right: 2, child: Container(
              width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF10B981),
                shape: BoxShape.circle, border: Border.all(color: AppTheme.backgroundColor, width: 2)))),
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

  Widget _shimmerList() => Shimmer.fromColors(
    baseColor: AppTheme.cardColor, highlightColor: const Color(0xFF2A2740),
    child: ListView.builder(itemCount: 8, itemBuilder: (_, __) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), height: 72,
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)))));

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppTheme.textSecondary),
    const SizedBox(height: 16),
    Text('Henüz mesajın yok', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text("Keşfet'ten birileriyle tanış!", style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
  ]));

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Şimdi';
    if (d.inHours < 1) return '${d.inMinutes}dk';
    if (d.inDays < 1) return '${d.inHours}s';
    if (d.inDays < 7) return '${d.inDays}g';
    return '${dt.day}/${dt.month}';
  }
}
