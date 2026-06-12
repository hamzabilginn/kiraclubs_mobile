import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../services/api_service.dart';
import '../../services/pusher_service.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final UserModel partner;
  const ChatScreen({Key? key, required this.partner}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _api      = ApiService();
  final PusherService _pusher = PusherService();
  final _msgCtrl             = TextEditingController();
  final _scrollCtrl          = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _pusherChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _initPusher();
  }

  @override
  void dispose() {
    if (_pusherChannel != null) {
      _pusher.unsubscribe(_pusherChannel!);
    }
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _initPusher() {
    final myId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    if (myId == null) return;

    _pusherChannel = 'private-chat.$myId';
    _pusher.subscribe(_pusherChannel!, (event) {
      debugPrint("Pusher Chat Event: ${event.eventName}");
      
      final Map<String, dynamic> data = event.data is String 
          ? jsonDecode(event.data) 
          : (event.data as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {};

      if (event.eventName.endsWith('MessageSent')) {
        final senderId = data['sender_id'] as int?;
        if (senderId == widget.partner.id) {
          final newMsg = MessageModel.fromJson(data);
          if (mounted) {
            setState(() {
              _messages.add(newMsg);
            });
            _scrollToBottom();
            _api.markAsRead(widget.partner.id).catchError((_) {});
          }
        }
      } else if (event.eventName.endsWith('MessageRead')) {
        final readerId = (data['readerId'] ?? data['reader_id']) as int?;
        if (readerId == widget.partner.id) {
          if (mounted) {
            setState(() {
              _messages = _messages.map((m) {
                if (m.isMine && !m.isRead) {
                  return MessageModel(
                    id: m.id,
                    body: m.body,
                    type: m.type,
                    isMine: m.isMine,
                    isRead: true,
                    createdAt: m.createdAt,
                  );
                }
                return m;
              }).toList();
            });
          }
        }
      }
    });
  }

  Future<void> _load() async {
    try {
      final data = await _api.getMessages(widget.partner.id);
      setState(() {
        _messages = data['messages'] as List<MessageModel>;
        _isLoading = false;
      });
      _scrollToBottom();
      _api.markAsRead(widget.partner.id).catchError((e) {
        debugPrint("Error marking messages as read: $e");
      });
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    _msgCtrl.clear();
    setState(() => _isSending = true);
    try {
      final msg = await _api.sendMessage(widget.partner.id, text);
      setState(() { _messages.add(msg); _isSending = false; });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      String errMsg = 'Mesaj gönderilemedi.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          errMsg = data['message'].toString();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errMsg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    appBar: _appBar(),
    body: Column(children: [
      Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _messages.length,
          itemBuilder: (_, i) => _bubble(_messages[i]),
        )),
      _inputBar(),
    ]),
  );

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: const Color(0xFF0F0D1A),
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
      onPressed: () => Navigator.pop(context),
    ),
    title: Row(children: [
      Stack(children: [
        CircleAvatar(radius: 20, backgroundColor: AppTheme.cardColor,
          backgroundImage: widget.partner.firstPhotoUrl != null
            ? CachedNetworkImageProvider(widget.partner.firstPhotoUrl!) : null,
          child: widget.partner.firstPhotoUrl == null
            ? Icon(Icons.person, color: AppTheme.textSecondary) : null),
        if (widget.partner.isOnline)
          Positioned(bottom: 1, right: 1, child: Container(
            width: 10, height: 10, decoration: BoxDecoration(
              color: const Color(0xFF10B981), shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0F0D1A), width: 1.5)))),
      ]),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.partner.name,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(
          widget.partner.isOnline
              ? 'Çevrimiçi'
              : _formatLastSeen(widget.partner.lastSeenAt, widget.partner.isOnline),
          style: TextStyle(
            color: widget.partner.isOnline ? const Color(0xFF10B981) : AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ]),
    ]),
    actions: [
      IconButton(
        icon: Icon(Icons.videocam_rounded, color: AppTheme.primaryColor),
        onPressed: () {/* Video call */},
      ),
      const SizedBox(width: 4),
    ],
  );

  Widget _bubble(MessageModel msg) {
    final isMine = msg.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMine ? AppTheme.primaryGradient : null,
          color: isMine ? null : AppTheme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (msg.type == 'image')
            ClipRRect(borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: msg.body, width: 200))
          else
            Text(msg.body, style: const TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_timeFormat(msg.createdAt),
              style: TextStyle(color: isMine ? Colors.white60 : AppTheme.textSecondary, fontSize: 11)),
            if (isMine) ...[
              const SizedBox(width: 4),
              Icon(Icons.done_all_rounded, size: 14,
                color: msg.isRead ? Colors.white : Colors.white38),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _inputBar() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF0F0D1A),
      border: Border(top: BorderSide(color: AppTheme.borderCol, width: 0.5)),
    ),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: SafeArea(
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor, borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderCol)),
            child: Row(children: [
              const SizedBox(width: 16),
              Expanded(child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 4, minLines: 1,
                decoration: InputDecoration.collapsed(
                  hintText: 'Mesaj yaz...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary)),
                onSubmitted: (_) => _send(),
              )),
              IconButton(
                icon: Icon(Icons.attach_file_rounded, color: AppTheme.textSecondary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Fotoğraf/Dosya gönderme özelliği yakında! 🚀'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 12, offset: const Offset(0, 4))]),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    ),
  );

  String _timeFormat(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatLastSeen(String? lastSeenIso, bool isOnline) {
    if (isOnline) return 'Çevrimiçi';
    if (lastSeenIso == null) return 'Çevrimdışı';
    try {
      final dt = DateTime.parse(lastSeenIso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 5) return 'Çevrimiçi';
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
      return 'Çevrimdışı';
    }
  }
}
