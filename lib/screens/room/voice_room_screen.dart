import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/pusher_service.dart';
import '../../services/api_service.dart';

class VoiceRoomScreen extends StatefulWidget {
  final Map<String, dynamic> room;

  const VoiceRoomScreen({Key? key, required this.room}) : super(key: key);

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  final PusherService _pusher = PusherService();
  
  RtcEngine? _engine;
  bool _joinedChannel = false;
  bool _isMuted = false;
  bool _isSpeaker = false; 
  bool _isHost = false;
  bool _isRaisingHand = false;
  bool _roomLocked = false;
  bool _isLoading = true;
  
  Map<String, dynamic>? _roomDetails;
  List<dynamic> _participants = []; // listeners
  List<dynamic> _speakers = [];
  Timer? _heartbeatTimer;

  // Chat integration
  List<dynamic> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _showChatTab = false;
  bool _hasNewMessages = false;

  // Emojis
  final List<_FloatingEmoji> _floatingEmojis = [];
  late AnimationController _emojiController;

  @override
  void initState() {
    super.initState();
    _emojiController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..addListener(() {
      setState(() {
        _floatingEmojis.removeWhere((e) => e.progress >= 1.0);
        for (var e in _floatingEmojis) {
          e.progress += 0.015;
        }
      });
    });
    _emojiController.repeat();

    _loadRoomState().then((_) {
      _initAgoraAndPusher();
      _loadChatMessages();
    });

    // Heartbeat every 10 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _joinedChannel) {
        _api.roomHeartbeat(widget.room['id']);
      }
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _emojiController.dispose();
    _messageController.dispose();
    _chatScrollController.dispose();
    _leaveChannel();
    super.dispose();
  }

  Future<void> _loadRoomState() async {
    try {
      final res = await _api.getRoomDetails(widget.room['id']);
      if (res['success'] == true) {
        setState(() {
          _roomDetails = res['room'];
          _speakers = res['speakers'] ?? [];
          _participants = res['listeners'] ?? [];
          _roomLocked = _roomDetails?['is_locked'] ?? false;
          
          final String myRole = res['my_role'] ?? 'listener';
          _isHost = (myRole == 'host');
          _isSpeaker = (myRole == 'host' || myRole == 'speaker');
          _isRaisingHand = res['is_raising_hand'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load Room State Exception: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initAgoraAndPusher() async {
    // Request microphone permission
    await Permission.microphone.request();

    // 1. Join Agora RTC
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: '9f3039b3616544d5a96acefcdc0f04ef', // Test Mode ID
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint("Agora Voice Room Joined Success");
          setState(() => _joinedChannel = true);
        },
        onUserMuteAudio: (connection, remoteUid, muted) {
          debugPrint("Remote speaker $remoteUid muted: $muted");
        },
      ));

      await _engine!.setClientRole(
        role: _isSpeaker ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
      );

      await _engine!.enableAudio();
      
      // Join Channel using room ID
      await _engine!.joinChannel(
        token: '', // No Token required in test mode
        channelId: 'room_${widget.room['id']}',
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );
    } catch (e) {
      debugPrint("Agora Init Exception: $e");
    }

    // 2. Subscribe to Pusher Presence Channel
    final channelName = 'presence-room.${widget.room['id']}';
    _pusher.subscribe(channelName, (event) {
      debugPrint("Pusher Voice Room Event: ${event.eventName}");
      
      final Map<String, dynamic> data = event.data is String 
          ? jsonDecode(event.data) 
          : (event.data as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {};

      if (event.eventName.endsWith('RoomParticipantJoined')) {
        _loadRoomState();
      } 
      else if (event.eventName.endsWith('RoomParticipantLeft')) {
        final leftUserId = data['userId'];
        final hostId = _roomDetails?['host_id'];
        if (leftUserId == hostId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Kurucu odadan ayrıldı. Oda kapatılıyor.'),
              behavior: SnackBarBehavior.floating,
            ));
            Navigator.pop(context);
          }
        } else {
          _loadRoomState();
        }
      } 
      else if (event.eventName.endsWith('RoomRoleChanged')) {
        _loadRoomState().then((_) {
          // Update Agora client role if the role change affected this user
          final myId = Provider.of<AuthProvider>(context, listen: false).user?.id;
          if (data['userId'] == myId) {
            _engine?.setClientRole(
              role: _isSpeaker ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
            );
          }
        });
      } 
      else if (event.eventName.endsWith('RoomLockToggled')) {
        setState(() {
          _roomLocked = data['isLocked'] ?? false;
        });
      } 
      else if (event.eventName.endsWith('RoomHandRaised')) {
        _loadRoomState();
      } 
      else if (event.eventName.endsWith('RoomEmojiSent')) {
        _spawnEmoji(data['emoji'] ?? '🔥');
      } 
      else if (event.eventName.endsWith('RoomMessageSent')) {
        final rawMsg = data['message'];
        final Map<String, dynamic> messageData = rawMsg is String
            ? jsonDecode(rawMsg)
            : (rawMsg as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {};
        
        final myId = Provider.of<AuthProvider>(context, listen: false).user?.id;
        final senderId = messageData['user']?['id'];
        
        if (senderId != myId) {
          setState(() {
            _messages.add(messageData);
            if (!_showChatTab) {
              _hasNewMessages = true;
            }
          });
          _scrollToBottom();
        }
      }
      else if (event.eventName.endsWith('RoomInvitationSent')) {
        final myId = Provider.of<AuthProvider>(context, listen: false).user?.id;
        if (data['userId'] == myId && mounted) {
          _showInvitationDialog();
        }
      }
    });
  }

  Future<void> _leaveChannel() async {
    await _pusher.unsubscribe('presence-room.${widget.room['id']}');
    try {
      await _api.leaveRoom(widget.room['id']);
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
  }

  void _spawnEmoji(String emoji) {
    if (!mounted) return;
    setState(() {
      _floatingEmojis.add(_FloatingEmoji(
        emoji: emoji,
        xOffset: Random().nextDouble() * 100 - 50,
        progress: 0.0,
      ));
    });
  }

  Future<void> _sendEmoji(String emoji) async {
    _spawnEmoji(emoji);
    try {
      await _api.sendRoomEmoji(widget.room['id'], emoji);
    } catch (_) {}
  }

  Future<void> _loadChatMessages() async {
    try {
      final messagesRes = await _api.getRoomMessages(widget.room['id']);
      setState(() {
        _messages = messagesRes;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Load Chat Messages Exception: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendChatMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    
    try {
      final res = await _api.sendRoomMessage(widget.room['id'], text);
      if (res['success'] == true) {
        setState(() {
          _messages.add(res['message']);
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Send Room Message Error: $e");
    }
  }

  Widget _buildChatMessageNode(Map<String, dynamic> msg, bool isMe) {
    final user = msg['user'] ?? {};
    final String name = user['name'] ?? 'Kullanıcı';
    final String? avatarUrl = user['avatar_url'];
    final String messageText = msg['message'] ?? '';
    final String vipLevel = user['vip_level'] ?? 'none';
    final bool isVip = vipLevel != 'none';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
            backgroundColor: AppTheme.cardColor,
            child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white30, size: 14) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isMe ? Colors.blueAccent : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isVip) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('VIP', style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F1C2F),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.zero,
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    messageText,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine?.muteLocalAudioStream(_isMuted);
  }

  Future<void> _toggleLock() async {
    try {
      final res = await _api.toggleRoomLock(widget.room['id']);
      if (res['success'] == true) {
        setState(() {
          _roomLocked = res['is_locked'] ?? !_roomLocked;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _raiseHand() async {
    try {
      if (_isRaisingHand) {
        // Lower hand
        final myId = Provider.of<AuthProvider>(context, listen: false).user?.id;
        if (myId != null) {
          await _api.lowerHand(widget.room['id'], myId);
          setState(() => _isRaisingHand = false);
        }
      } else {
        // Raise hand
        await _api.raiseHand(widget.room['id']);
        setState(() => _isRaisingHand = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Konuşma talebi (El Kaldırma) iletildi! ✋'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _showInvitationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Kürsü Daveti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Oda yöneticisi sizi konuşmacı olarak kürsüye davet etti.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.acceptSpeakInvite(widget.room['id']);
                _loadRoomState();
              } catch (_) {}
            },
            child: const Text('Kabul Et', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Reddet', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _manageUser(Map<String, dynamic> userMap, bool fromSpeakers) {
    if (!_isHost) return;
    final myId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    if (userMap['id'] == myId) return; // Can't manage self

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(userMap['name'] ?? 'Kullanıcı Yönetimi', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (fromSpeakers)
              ListTile(
                leading: const Icon(Icons.mic_off_rounded, color: Colors.amber),
                title: const Text('Dinleyici Yap', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.demoteSpeaker(widget.room['id'], userMap['id']);
                    _loadRoomState();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                  }
                },
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.mic_rounded, color: Colors.green),
                title: const Text('Konuşmacı Daveti Gönder', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.inviteToSpeak(widget.room['id'], userMap['id']);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konuşma daveti gönderildi.')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                  }
                },
              ),
              if (userMap['is_raising_hand'] == true)
                ListTile(
                  leading: const Icon(Icons.front_hand, color: Colors.amber),
                  title: const Text('Elini İndir', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await _api.lowerHand(widget.room['id'], userMap['id']);
                      _loadRoomState();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                    }
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.gavel_rounded, color: Colors.red),
              title: const Text('Odadan At (Kick)', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await _api.kickUser(widget.room['id'], userMap['id']);
                  _loadRoomState();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHandRaisesSheet() {
    final handRaisers = _participants.where((p) => p['is_raising_hand'] == true).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF151324),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Konuşma Talepleri', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: handRaisers.isEmpty
                  ? const Center(child: Text('Talebi olan kullanıcı yok.', style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.builder(
                      itemCount: handRaisers.length,
                      itemBuilder: (context, index) {
                        final req = handRaisers[index];
                        return ListTile(
                          title: Text(req['name'] ?? '', style: const TextStyle(color: Colors.white)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  try {
                                    await _api.inviteToSpeak(widget.room['id'], req['id']);
                                    ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Davet iletildi.')));
                                  } catch (_) {}
                                },
                                child: const Text('Kabul Et', style: TextStyle(color: Colors.green)),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  try {
                                    await _api.lowerHand(widget.room['id'], req['id']);
                                    _loadRoomState();
                                  } catch (_) {}
                                },
                                child: const Text('Reddet', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final hasHandRaisers = _participants.any((p) => p['is_raising_hand'] == true);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        title: Row(
          children: [
            if (_roomLocked)
              const Icon(Icons.lock_rounded, color: Colors.amber, size: 16)
            else
              const Icon(Icons.lock_open_rounded, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _roomDetails?['name'] ?? widget.room['name'] ?? 'Sesli Oda', 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Room category & Host badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(_roomDetails?['category'] ?? widget.room['category'] ?? 'Sohbet', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    const Text('🎙️ Canlı Yayın Odası', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),

              // Speakers / Podium Section
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.8),
                    itemCount: _speakers.length + (8 - _speakers.length).clamp(1, 8), 
                    itemBuilder: (context, index) {
                      if (index < _speakers.length) {
                        final speaker = _speakers[index];
                        final isSpeakerHost = speaker['role'] == 'host';
                        return GestureDetector(
                          onTap: () => _manageUser(speaker, true),
                          child: _buildSpeakerNode(speaker['name'] ?? '', speaker['avatar_url'], isSpeakerHost),
                        );
                      }
                      return _buildEmptyPodiumNode();
                    },
                  ),
                ),
              ),

              const Divider(color: Colors.white10, height: 1),

              // Listeners / Chat Section
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tab Header
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _showChatTab = false),
                            child: Text(
                              'DİNLEYİCİLER (${_participants.length})',
                              style: TextStyle(
                                color: !_showChatTab ? Colors.white : AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showChatTab = true;
                                _hasNewMessages = false;
                              });
                              _scrollToBottom();
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Text(
                                  'SOHBET',
                                  style: TextStyle(
                                    color: _showChatTab ? Colors.white : AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (_hasNewMessages && !_showChatTab)
                                  Positioned(
                                    right: -8,
                                    top: -4,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _showChatTab
                            ? Column(
                                children: [
                                  Expanded(
                                    child: _messages.isEmpty
                                        ? const Center(child: Text('Henüz mesaj yok.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)))
                                        : ListView.builder(
                                            controller: _chatScrollController,
                                            itemCount: _messages.length,
                                            itemBuilder: (context, index) {
                                              final msg = _messages[index];
                                              final myId = Provider.of<AuthProvider>(context, listen: false).user?.id;
                                              final isMe = msg['user']?['id'] == myId;
                                              return _buildChatMessageNode(msg, isMe);
                                            },
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _messageController,
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                          decoration: InputDecoration(
                                            hintText: 'Mesaj yazın...',
                                            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                                            filled: true,
                                            fillColor: const Color(0xFF1F1C2F),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(20),
                                              borderSide: BorderSide.none,
                                            ),
                                          ),
                                          onSubmitted: (_) => _sendChatMessage(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _sendChatMessage,
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFFEC4899)]),
                                          ),
                                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                        ),
                                      )
                                    ],
                                  )
                                ],
                              )
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.8),
                                itemCount: _participants.length,
                                itemBuilder: (context, index) {
                                  final listener = _participants[index];
                                  return GestureDetector(
                                    onTap: () => _manageUser(listener, false),
                                    child: _buildListenerNode(listener['name'] ?? '', listener['avatar_url'], listener['is_raising_hand'] == true),
                                  );
                                },
                              ),
                      )
                    ],
                  ),
                ),
              ),

              // Bottom control bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Color(0xFF0F0D1A), border: Border(top: BorderSide(color: AppTheme.borderCol))),
                child: Row(
                  children: [
                    // Mute / Unmute (only for speaker/host)
                    if (_isSpeaker)
                      FloatingActionButton(
                        heroTag: 'voice_mute',
                        backgroundColor: _isMuted ? Colors.red : const Color(0xFF3B82F6),
                        onPressed: _toggleMute,
                        child: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                      )
                    else
                      FloatingActionButton(
                        heroTag: 'voice_raise',
                        backgroundColor: _isRaisingHand ? Colors.amber : AppTheme.cardColor,
                        onPressed: _raiseHand,
                        child: Icon(Icons.front_hand_outlined, color: _isRaisingHand ? Colors.black : Colors.white),
                      ),
                    const SizedBox(width: 12),

                    // Host Controls (Lock Room & Hand raises listing)
                    if (_isHost) ...[
                      FloatingActionButton(
                        heroTag: 'voice_lock',
                        backgroundColor: _roomLocked ? Colors.amber : const Color(0xFF10B981),
                        onPressed: _toggleLock,
                        child: Icon(_roomLocked ? Icons.lock : Icons.lock_open, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        heroTag: 'voice_hands',
                        backgroundColor: hasHandRaisers ? Colors.amber : const Color(0xFF4B5563),
                        onPressed: _showHandRaisesSheet,
                        child: Icon(Icons.front_hand, color: hasHandRaisers ? Colors.black : Colors.white),
                      ),
                      const SizedBox(width: 12),
                    ],

                    const Spacer(),

                    // Emoji floating panel trigger
                    Row(
                      children: ['👏', '❤️', '🔥', '😂', '😮'].map((emoji) {
                        return GestureDetector(
                          onTap: () => _sendEmoji(emoji),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppTheme.cardColor,
                              child: Text(emoji, style: const TextStyle(fontSize: 16)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              )
            ],
          ),

          // Flying Emojis Overlay
          ..._floatingEmojis.map((e) {
            final double scale = 1.0 - (e.progress * 0.2);
            final double opacity = 1.0 - e.progress;
            final double y = MediaQuery.of(context).size.height * 0.75 - (e.progress * 300);
            final double x = MediaQuery.of(context).size.width * 0.7 + e.xOffset + (sin(e.progress * 5 * pi) * 20);

            return Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Text(e.emoji, style: const TextStyle(fontSize: 32)),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSpeakerNode(String name, String? avatarUrl, bool isHost) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isHost ? Colors.amber : const Color(0xFF4F46E5), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: CircleAvatar(
                  backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                  backgroundColor: AppTheme.backgroundColor,
                  child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white70) : null,
                ),
              ),
            ),
            if (isHost)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                  child: const Icon(Icons.star, size: 8, color: Colors.black),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildEmptyPodiumNode() {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: AppTheme.cardColor, shape: BoxShape.circle, border: Border.all(color: Colors.white10, width: 1.5)),
          child: const Center(child: Icon(Icons.add, color: Colors.white24, size: 20)),
        ),
        const SizedBox(height: 6),
        const Text('Kürsü Boş', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
      ],
    );
  }

  Widget _buildListenerNode(String name, String? avatarUrl, bool isRaisingHand) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
              backgroundColor: AppTheme.cardColor,
              child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white30, size: 20) : null,
            ),
            if (isRaisingHand)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                  child: const Icon(Icons.front_hand, size: 8, color: Colors.black),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _FloatingEmoji {
  final String emoji;
  final double xOffset;
  double progress;

  _FloatingEmoji({required this.emoji, required this.xOffset, required this.progress});
}
