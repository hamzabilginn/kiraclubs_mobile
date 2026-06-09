import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final UserModel partner;
  const ChatScreen({Key? key, required this.partner}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _api      = ApiService();
  final _msgCtrl             = TextEditingController();
  final _scrollCtrl          = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final data = await _api.getMessages(widget.partner.id);
      setState(() {
        _messages = data['messages'] as List<MessageModel>;
        _isLoading = false;
      });
      _scrollToBottom();
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
    } catch (e) { setState(() => _isSending = false); }
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
          backgroundImage: widget.partner.avatarUrl != null
            ? CachedNetworkImageProvider(widget.partner.avatarUrl!) : null,
          child: widget.partner.avatarUrl == null
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
        Text(widget.partner.isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
          style: TextStyle(color: widget.partner.isOnline
            ? const Color(0xFF10B981) : AppTheme.textSecondary, fontSize: 12)),
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
                onPressed: () {},
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
}
