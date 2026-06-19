import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../services/api_service.dart';
import '../../services/pusher_service.dart';
import '../../providers/auth_provider.dart';
import '../call/call_screen.dart';

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

  // Recording variables
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  int _recordDuration = 0;
  Timer? _recordTimer;

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
    _audioRecorder.dispose();
    _recordTimer?.cancel();
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

  // ─── Image Uploading ───────────────────────────────────────────────────────

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile == null) return;

      setState(() => _isSending = true);

      final msg = await _api.uploadChatImage(widget.partner.id, pickedFile.path);

      setState(() {
        _messages.add(msg);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      String errMsg = 'Fotoğraf gönderilemedi.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          errMsg = data['message'].toString();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errMsg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor),
              title: const Text('Galeri', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor),
              title: const Text('Kamera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Voice Messages ────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      final hasMicPermission = await Permission.microphone.request();
      if (hasMicPermission != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mikrofon izni verilmedi.'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordDuration = 0;
        _recordingPath = path;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration++;
        });
      });
    } catch (e) {
      debugPrint("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordDuration = 0;
    });

    if (path != null && send) {
      _sendVoice(path);
    } else if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _sendVoice(String filePath) async {
    setState(() => _isSending = true);
    try {
      final msg = await _api.uploadChatVoice(widget.partner.id, filePath);
      setState(() {
        _messages.add(msg);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      String errMsg = 'Ses kaydı gönderilemedi.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          errMsg = data['message'].toString();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errMsg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─── Gifts Integration ─────────────────────────────────────────────────────

  void _showGiftSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0D1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return FutureBuilder<List<dynamic>>(
              future: _api.getGifts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 350,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    height: 250,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Hediyeler yüklenemedi.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                final gifts = snapshot.data ?? [];
                if (gifts.isEmpty) {
                  return Container(
                    height: 250,
                    alignment: Alignment.center,
                    child: Text(
                      'Aktif hediye bulunamadı.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }

                return Container(
                  height: MediaQuery.of(context).size.height * 0.55,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hediye Gönder 🎁',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.82,
                          ),
                          itemCount: gifts.length,
                          itemBuilder: (context, idx) {
                            final g = gifts[idx];
                            final emoji = g['emoji'] ?? '🎁';
                            final name = g['name'] ?? 'Hediye';
                            final price = (g['price'] is int)
                                ? (g['price'] as int)
                                : double.parse(g['price'].toString()).toInt();
                            final giftId = g['id'] as int;

                            return GestureDetector(
                              onTap: () => _confirmSendGift(giftId, emoji, name, price),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.borderCol,
                                    width: 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 38),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.pink.shade500.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.monetization_on_rounded,
                                            color: Colors.pink.shade400,
                                            size: 11,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '$price',
                                            style: TextStyle(
                                              color: Colors.pink.shade300,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmSendGift(int giftId, String emoji, String name, int price) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF161426),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$name Gönderilsin mi?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Bu kullanıcıya $name göndermek istiyor musunuz?\n\nHesabınızdan $price kredi tahsil edilecektir.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            child: const Text('İptal', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Gönder'),
            onPressed: () {
              Navigator.pop(dialogCtx); // Close Dialog
              Navigator.pop(context); // Close BottomSheet
              _executeSendGift(giftId, emoji, name, price);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _executeSendGift(int giftId, String emoji, String name, int price) async {
    setState(() => _isSending = true);
    try {
      final msg = await _api.sendGift(widget.partner.id, giftId);
      setState(() {
        _messages.add(msg);
        _isSending = false;
      });
      _scrollToBottom();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name başarıyla gönderildi! 🎁'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
      ));
    } catch (e) {
      setState(() => _isSending = false);
      String errMsg = 'Hediye gönderilemedi.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          errMsg = data['message'].toString();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errMsg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _sendDirectMessage(String text) async {
    if (text.isEmpty || _isSending) return;
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

  Widget _quickSuggestionsBar() {
    const suggestions = [
      'Harika gözlerin var! ✨',
      'Selam, bugün nasılsın? 🌹',
      'Hadi görüntülü konuşalım! 📹',
      'Sana güzel bir hediye göndermek istiyorum... 🎁',
    ];
    return Container(
      height: 44,
      color: const Color(0xFF0F0D1A),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final text = suggestions[index];
          return GestureDetector(
            onTap: () => _sendDirectMessage(text),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _verifiedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D3557).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF457B9D).withOpacity(0.4), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF3B82F6),
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'Bu kullanıcı, kimlik bilgileri doğrulanmış onaylı bir üyedir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.blue.shade100,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPartnerVerified = widget.partner.verificationStatus == 'verified';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _appBar(),
      body: Column(children: [
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (isPartnerVerified ? 1 : 0),
              itemBuilder: (_, i) {
                if (isPartnerVerified) {
                  if (i == 0) {
                    return _verifiedBanner();
                  }
                  return _bubble(_messages[i - 1]);
                }
                return _bubble(_messages[i]);
              },
            )),
        if (!_isRecording) _quickSuggestionsBar(),
        _isRecording ? _recordingInputBar() : _normalInputBar(),
      ]),
    );
  }

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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.partner.name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            if (widget.partner.isVip) ...[
              const SizedBox(width: 4),
              Text(
                widget.partner.vipLevel == 'platinum' ? '💜' : widget.partner.vipLevel == 'gold' ? '⭐' : '🥈',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (widget.partner.verificationStatus == 'verified') ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: Colors.blue, size: 16),
            ],
          ],
        ),
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(chatUser: widget.partner),
            ),
          );
        },
      ),
      const SizedBox(width: 4),
    ],
  );

  Widget _bubble(MessageModel msg) {
    final isMine = msg.isMine;

    if (msg.type == 'voice') {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: VoicePlayBubble(
            url: msg.body,
            isMine: isMine,
            createdAt: msg.createdAt,
          ),
        ),
      );
    }

    if (msg.type == 'gift') {
      String emoji = '🎁';
      if (msg.body.startsWith('[GIFT:')) {
        final parts = msg.body.replaceAll(']', '').split(':');
        if (parts.length > 2) {
          emoji = parts[2];
        }
      } else {
        emoji = msg.body;
      }

      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
          padding: const EdgeInsets.all(16),
          decoration: isMine
              ? BoxDecoration(
                  color: Colors.pink.shade500.withOpacity(0.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(6),
                  ),
                  border: Border.all(color: Colors.pink.shade400.withOpacity(0.7), width: 1.5),
                )
              : BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.pink.shade400, Colors.purple.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(24),
                  ),
                  border: Border.all(color: Colors.amber.shade400, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.shade500.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 8),
              Text(
                isMine ? 'Hediye Gönderdin' : 'Sana Bir Hediye Gönderdi!',
                style: TextStyle(
                  color: isMine ? Colors.pink.shade200 : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _timeFormat(msg.createdAt),
                    style: TextStyle(
                      color: isMine ? Colors.white54 : Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: msg.isRead ? Colors.white : Colors.white38,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (msg.type == 'image')
              GestureDetector(
                onTap: () => _viewFullScreenImage(msg.body),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: msg.body,
                    width: 200,
                    placeholder: (_, __) => Container(
                      width: 200,
                      height: 150,
                      color: Colors.white10,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                    errorWidget: (_, __, ___) => const Icon(Icons.error),
                  ),
                ),
              )
            else
              Text(msg.body, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeFormat(msg.createdAt),
                  style: TextStyle(
                    color: isMine ? Colors.white60 : AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 14,
                    color: msg.isRead ? Colors.white : Colors.white38,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewFullScreenImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                placeholder: (_, __) => const CircularProgressIndicator(),
                errorWidget: (_, __, ___) => const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }  Widget _normalInputBar() {
    final showSend = _msgCtrl.text.trim().isNotEmpty || _isSending;
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    
    String hintText = 'Mesajını yaz...';
    if (currentUser != null) {
      if (currentUser.gender == 'female') {
        hintText = 'Mesajını yaz... (Ücretsiz!)';
      } else {
        final isVipGoldOrPlat = (currentUser.vipLevel == 'gold' || currentUser.vipLevel == 'platinum') && currentUser.isVip;
        if (isVipGoldOrPlat) {
          hintText = 'Mesajını yaz... (Ücretsiz!)';
        } else {
          hintText = 'Mesajını yaz... (15 Kredi)';
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0D1A),
        border: Border(top: BorderSide(color: AppTheme.borderCol, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: SafeArea(
        child: Row(
          children: [
            GestureDetector(
              onTap: _showAttachmentOptions,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_outlined, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            /*
            GestureDetector(
              onTap: _showGiftSheet,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            */
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mic_none_outlined, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161426),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  onChanged: (text) {
                    setState(() {});
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 4,
                  minLines: 1,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: showSend ? _send : null,
              child: Opacity(
                opacity: showSend ? 1.0 : 0.4,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordingInputBar() => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0D1A),
          border: Border(top: BorderSide(color: AppTheme.borderCol, width: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 28),
                onPressed: () => _stopRecording(send: false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.borderCol),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Ses Kaydediliyor...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        _formatRecordDuration(_recordDuration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _stopRecording(send: true),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      );

  String _formatRecordDuration(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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

  String _timeFormat(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class VoicePlayBubble extends StatefulWidget {
  final String url;
  final bool isMine;
  final DateTime createdAt;

  const VoicePlayBubble({
    Key? key,
    required this.url,
    required this.isMine,
    required this.createdAt,
  }) : super(key: key);

  @override
  State<VoicePlayBubble> createState() => _VoicePlayBubbleState();
}

class _VoicePlayBubbleState extends State<VoicePlayBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  void _initAudio() {
    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _durSub = _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _posSub = _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.url));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString();
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMine ? const Color(0xFF6366F1) : const Color(0xFF1E293B);
    final buttonColor = widget.isMine ? const Color(0xFF4F46E5) : const Color(0xFF4338CA);
    final progressColor = widget.isMine ? Colors.white60 : Colors.indigo.shade400;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(widget.isMine ? 18 : 4),
          bottomRight: Radius.circular(widget.isMine ? 4 : 18),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: buttonColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: progressColor,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    min: 0.0,
                    max: _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    value: _position.inMilliseconds.toDouble().clamp(
                        0.0,
                        _duration.inMilliseconds.toDouble() > 0
                            ? _duration.inMilliseconds.toDouble()
                            : 1.0),
                    onChanged: (val) {
                      _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying
                          ? _formatDuration(_position)
                          : _formatDuration(_duration),
                      style: TextStyle(
                        color: widget.isMine ? Colors.white70 : Colors.grey.shade400,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      _timeFormat(widget.createdAt),
                      style: TextStyle(
                        color: widget.isMine ? Colors.white70 : Colors.grey.shade400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeFormat(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
