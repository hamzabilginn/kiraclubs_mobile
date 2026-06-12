import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class CallScreen extends StatefulWidget {
  final UserModel chatUser;
  static bool isActive = false;

  const CallScreen({Key? key, required this.chatUser}) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final ApiService _apiService = ApiService();
  RtcEngine? _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isRinging = true;
  Timer? _ringTimer;
  String? _channelName;

  @override
  void initState() {
    super.initState();
    CallScreen.isActive = true;
    _startRingSimulation();
  }

  @override
  void dispose() {
    CallScreen.isActive = false;
    _ringTimer?.cancel();
    _destroyAgora();
    super.dispose();
  }

  bool _isImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return !lower.endsWith('.mov') &&
           !lower.endsWith('.mp4') &&
           !lower.endsWith('.avi') &&
           !lower.endsWith('.mkv') &&
           !lower.endsWith('.webm') &&
           !lower.endsWith('.3gp');
  }

  // Simulate call connection after 3 seconds of ringing
  void _startRingSimulation() {
    _ringTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _isRinging = false;
      });
      _initAgora();
    });
  }

  Future<void> _initAgora() async {
    // Request camera and microphone permissions
    await [Permission.microphone, Permission.camera].request();

    try {
      final callInfo = await _apiService.initiateCall(widget.chatUser.id);
      _channelName = callInfo['channel_name'];
      
      // Create Agora engine instance
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: callInfo['app_id'],
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            setState(() {
              _localUserJoined = true;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            setState(() {
              _remoteUid = null;
            });
            _handleEndCall();
          },
        ),
      );

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableVideo();
      await _engine!.startPreview();

      await _engine!.joinChannel(
        token: callInfo['agora_token'],
        channelId: _channelName!,
        uid: 0,
        options: const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      // Fallback for emulator environments/errors
      debugPrint('Agora Init Error: $e');
      setState(() {
        _localUserJoined = true;
        _remoteUid = 999; // Mock remote user ID for testing fallback UI
      });
    }
  }

  Future<void> _destroyAgora() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
  }

  void _handleEndCall() {
    Navigator.pop(context);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine?.muteLocalAudioStream(_isMuted);
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    _engine?.muteLocalVideoStream(_isCameraOff);
  }

  // Widget for local video feed
  Widget _buildLocalVideo() {
    if (_isCameraOff) {
      return Container(
        color: Colors.black54,
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white, size: 30),
        ),
      );
    }
    
    if (_engine != null && _localUserJoined && _remoteUid != 999) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }
    // Emulator Mock preview
    return Container(
      color: const Color(0xFF1E1B2E),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white70, size: 40),
      ),
    );
  }

  // Widget for remote video feed
  Widget _buildRemoteVideo() {
    if (_remoteUid != null && _remoteUid != 999 && _engine != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: _channelName),
        ),
      );
    }

    // Emulator Mock view (Renders target user's profile image as active feed)
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isImageUrl(widget.chatUser.formattedAvatarUrl))
          Image.network(
            widget.chatUser.formattedAvatarUrl!,
            fit: BoxFit.cover,
          )
        else
          Container(
            color: const Color(0xFF1E1B2E),
            child: const Icon(Icons.person, color: Colors.white70, size: 80),
          ),
        // Overlay banner
        Container(
          color: Colors.black.withOpacity(0.3),
          child: const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 80.0),
              child: Text(
                'Simüle Edilen Görüntülü Görüşme',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRinging) {
      // Ringing screen layout
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_isImageUrl(widget.chatUser.formattedAvatarUrl))
              Image.network(
                widget.chatUser.formattedAvatarUrl!,
                fit: BoxFit.cover,
              )
            else
              Container(color: Colors.black87),
            Container(color: Colors.black.withOpacity(0.65)),
            
            // Central UI content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ringing Pulse Animation (profile pic)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentColor.withOpacity(0.3), width: 4),
                  ),
                  child: CircleAvatar(
                    backgroundImage: _isImageUrl(widget.chatUser.formattedAvatarUrl)
                        ? NetworkImage(widget.chatUser.formattedAvatarUrl!)
                        : null,
                    radius: 70,
                    child: !_isImageUrl(widget.chatUser.formattedAvatarUrl)
                        ? const Icon(Icons.person, size: 70, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.chatUser.name,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aranıyor...',
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 120),
                
                // End Call button
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: _handleEndCall,
                  child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Call active screen layout
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Remote Video Feed
          _buildRemoteVideo(),
          
          // Local Camera Preview (Mini Floating Window)
          Positioned(
            top: 50,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: _buildLocalVideo(),
              ),
            ),
          ),
          
          // Control Actions Overlay
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute audio
                FloatingActionButton(
                  heroTag: 'mute_btn',
                  backgroundColor: _isMuted ? Colors.white : Colors.white24,
                  onPressed: _toggleMute,
                  child: Icon(
                    _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.black : Colors.white,
                  ),
                ),
                // End call
                FloatingActionButton(
                  heroTag: 'end_btn',
                  backgroundColor: Colors.red,
                  onPressed: _handleEndCall,
                  child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                ),
                // Toggle camera
                FloatingActionButton(
                  heroTag: 'cam_btn',
                  backgroundColor: _isCameraOff ? Colors.white : Colors.white24,
                  onPressed: _toggleCamera,
                  child: Icon(
                    _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    color: _isCameraOff ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
