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
  bool _isSpeakerphoneOn = true;
  bool _isRinging = true;
  Timer? _ringTimer;
  String? _channelName;

  // Call duration and heartbeat sync timers
  int _callDuration = 0;
  Timer? _durationTimer;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    CallScreen.isActive = true;
    _initAgora(); // Initialize Agora immediately in the background
    _startRingSimulation();
  }

  @override
  void dispose() {
    CallScreen.isActive = false;
    _ringTimer?.cancel();
    _durationTimer?.cancel();
    _heartbeatTimer?.cancel();
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
      if (mounted) {
        setState(() {
          _isRinging = false;
        });
      }
    });
  }

  Future<void> _initAgora() async {
    // Request camera and microphone permissions
    final statuses = await [Permission.microphone, Permission.camera].request();
    debugPrint('CallScreen: Microphone permission status: ${statuses[Permission.microphone]}');
    debugPrint('CallScreen: Camera permission status: ${statuses[Permission.camera]}');

    if (statuses[Permission.microphone] != PermissionStatus.granted ||
        statuses[Permission.camera] != PermissionStatus.granted) {
      debugPrint('CallScreen WARNING: Microphone or Camera permission not granted!');
    }

    try {
      final callInfo = await _apiService.initiateCall(widget.chatUser.id);
      _channelName = callInfo['channel_name'];
      debugPrint('CallScreen: Initiate call info received. Channel: $_channelName');
      
      // Create Agora engine instance
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: callInfo['app_id'],
        channelProfile: ChannelProfileType.channelProfileCommunication,
        areaCode: AreaCode.areaCodeEu.value(), // European servers for lowest latency in Turkey/Europe
      ));

      // Use Music Standard profile to force a 48kHz sample rate. This matches standard WebRTC expectations
      // on iOS Safari and prevents the audio resampling bug that causes metallic buzzing.
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicStandard,
        scenario: AudioScenarioType.audioScenarioDefault,
      );

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("CallScreen: local user joined success");
            setState(() {
              _localUserJoined = true;
            });
            // Force audio route to speakerphone upon joining successfully
            _engine?.setEnableSpeakerphone(true).then((_) {
              debugPrint("CallScreen: setEnableSpeakerphone(true) completed");
            }).catchError((err) {
              debugPrint("CallScreen Error forcing speakerphone: $err");
            });
            _startCallTimers();
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("CallScreen: remote user joined: $remoteUid");
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("CallScreen: remote user offline: $remoteUid, reason: $reason");
            setState(() {
              _remoteUid = null;
            });
            _handleEndCall();
          },
          onLocalAudioStateChanged: (connection, state, error) {
            debugPrint("CallScreen: local audio state changed: $state, error: $error");
          },
          onRemoteAudioStateChanged: (connection, remoteUid, state, reason, elapsed) {
            debugPrint("CallScreen: remote audio state changed for user $remoteUid: $state, reason: $reason");
          },
        ),
      );

      await _engine!.enableAudio();
      await _engine!.enableVideo();
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);
      await _engine!.startPreview();

      debugPrint('CallScreen: Joining Agora channel: $_channelName');
      await _engine!.joinChannel(
        token: callInfo['agora_token'],
        channelId: _channelName!,
        uid: 0,
        options: const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          enableAudioRecordingOrPlayout: true,
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

  void _startCallTimers() {
    // 1. Duration timer
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });

    // 2. Heartbeat timer
    _heartbeatTimer?.cancel();
    // Send initial immediate heartbeat
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _sendHeartbeat();
    });
  }

  void _sendHeartbeat() async {
    if (!mounted) return;
    try {
      final res = await _apiService.sendHeartbeat(widget.chatUser.id);
      debugPrint("CallScreen Heartbeat success: ${res['success']}, balance: ${res['balance']}");
      if (res['success'] == false) {
        debugPrint("CallScreen Heartbeat termination requested by server.");
        _handleEndCall();
      }
    } catch (e) {
      debugPrint("CallScreen Error sending heartbeat: $e");
    }
  }

  void _handleEndCall() {
    if (_localUserJoined) {
      _apiService.endCall(
        widget.chatUser.id,
        duration: _callDuration,
        wasConnected: _localUserJoined,
      ).catchError((err) {
        debugPrint("CallScreen Error sending endCall API: $err");
        return <String, dynamic>{};
      });
    }
    if (mounted) {
      Navigator.pop(context);
    }
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

  void _toggleSpeakerphone() {
    setState(() {
      _isSpeakerphoneOn = !_isSpeakerphoneOn;
    });
    _engine?.setEnableSpeakerphone(_isSpeakerphoneOn).then((_) {
      debugPrint("CallScreen: setEnableSpeakerphone($_isSpeakerphoneOn) completed");
    }).catchError((err) {
      debugPrint("CallScreen Error setting speakerphone: $err");
    });
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
                // Toggle speakerphone
                FloatingActionButton(
                  heroTag: 'speaker_btn',
                  backgroundColor: _isSpeakerphoneOn ? Colors.white : Colors.white24,
                  onPressed: _toggleSpeakerphone,
                  child: Icon(
                    _isSpeakerphoneOn ? Icons.volume_up : Icons.volume_down,
                    color: _isSpeakerphoneOn ? Colors.black : Colors.white,
                  ),
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
                // End call
                FloatingActionButton(
                  heroTag: 'end_btn',
                  backgroundColor: Colors.red,
                  onPressed: _handleEndCall,
                  child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
