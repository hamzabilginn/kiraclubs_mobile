import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../discover/discover_screen.dart';
import '../chat/inbox_screen.dart';
import '../profile/my_profile_screen.dart';
import '../status/statuses_screen.dart';
import '../room/rooms_screen.dart';
import '../../services/pusher_service.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../call/call_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({Key? key}) : super(key: key);

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;
  BuildContext? _incomingCallDialogContext;

  @override
  void initState() {
    super.initState();
    _subscribeToIncomingCalls();
  }

  @override
  void dispose() {
    _unsubscribeFromIncomingCalls();
    super.dispose();
  }

  void _subscribeToIncomingCalls() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user != null) {
      PusherService().subscribe('private-user.${user.id}', (event) {
        if (event.eventName == 'CallInvited') {
          _showIncomingCallDialog(event.data);
        } else if (event.eventName == 'CallSignal') {
          final type = event.data['type'] as String?;
          if (type == 'hang-up') {
            _dismissIncomingCallDialog();
            _dismissActiveCall();
          }
        }
      });
    }
  }

  void _unsubscribeFromIncomingCalls() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user != null) {
      PusherService().unsubscribe('private-user.${user.id}');
    }
  }

  void _dismissIncomingCallDialog() {
    if (_incomingCallDialogContext != null) {
      Navigator.of(_incomingCallDialogContext!).pop();
      _incomingCallDialogContext = null;
    }
  }

  void _dismissActiveCall() {
    if (CallScreen.isActive) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showIncomingCallDialog(dynamic data) {
    if (data == null) return;
    if (CallScreen.isActive || _incomingCallDialogContext != null) return;

    final callerId = data['caller_id'] as int?;
    final callerName = data['caller_name'] as String? ?? 'Bilinmeyen Arayan';
    final callerAvatar = data['caller_avatar'] as String?;
    final roomId = data['room_id'] as String?;

    if (callerId == null || roomId == null) return;

    final callerUser = UserModel(
      id: callerId,
      name: callerName,
      avatarUrl: callerAvatar,
    );

    bool isImageUrl(String? url) {
      if (url == null || url.isEmpty) return false;
      final lower = url.toLowerCase();
      return !lower.endsWith('.mov') &&
             !lower.endsWith('.mp4') &&
             !lower.endsWith('.avi') &&
             !lower.endsWith('.mkv') &&
             !lower.endsWith('.webm') &&
             !lower.endsWith('.3gp');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _incomingCallDialogContext = dialogContext;
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: const Color(0xFF131124),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Gelen Arama',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.cardColor,
                    backgroundImage: isImageUrl(callerAvatar)
                        ? NetworkImage(callerAvatar!)
                        : null,
                    child: !isImageUrl(callerAvatar)
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sizi görüntülü aramaya davet ediyor...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton(
                        heroTag: 'decline_dialog_btn',
                        backgroundColor: Colors.red,
                        onPressed: () async {
                          _dismissIncomingCallDialog();
                          try {
                            await ApiService().endCall(callerId, duration: 0, wasConnected: false);
                          } catch (e) {
                            debugPrint('Error rejecting call: $e');
                          }
                        },
                        child: const Icon(Icons.call_end, color: Colors.white),
                      ),
                      FloatingActionButton(
                        heroTag: 'accept_dialog_btn',
                        backgroundColor: Colors.green,
                        onPressed: () {
                          _dismissIncomingCallDialog();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CallScreen(chatUser: callerUser),
                            ),
                          );
                        },
                        child: const Icon(Icons.call, color: Colors.white),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _incomingCallDialogContext = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    final List<Widget> screens = [];
    final List<Map<String, dynamic>> items = [];

    // 1. Keşfet
    screens.add(const DiscoverScreen());
    items.add({'icon': Icons.search_rounded, 'label': 'Keşfet'});

    // 2. Durumlar
    screens.add(const StatusesScreen());
    items.add({'icon': Icons.campaign_rounded, 'label': 'Durumlar'});

    // 3. Odalar
    screens.add(const RoomsScreen());
    items.add({'icon': Icons.mic_rounded, 'label': 'Odalar'});

    // 4. Mesajlarım
    screens.add(const InboxScreen());
    items.add({'icon': Icons.chat_bubble_rounded, 'label': 'Mesajlarım'});

    // 5. Ajansım (Dynamic)
    if (user != null && (user.isAgencyOwner || user.isPublisher)) {
      screens.add(const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: Text(
            'Ajans Yönetimi\nYakında mobil uygulamada da aktif olacak!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, height: 1.6),
          ),
        ),
      ));
      items.add({'icon': Icons.business_rounded, 'label': 'Ajansım'});
    }

    // 6. Profil
    screens.add(const MyProfileScreen());
    items.add({
      'icon': Icons.person_rounded, 
      'label': 'Profil',
      'avatarUrl': user?.avatarUrl,
    });

    // Prevent index out of bounds on role change
    if (_currentIndex >= screens.length) {
      _currentIndex = screens.length - 1;
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildNavBar(items),
    );
  }

  Widget _buildNavBar(List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0D1A),
        border: Border(top: BorderSide(color: AppTheme.borderCol, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              return _NavItem(
                icon: item['icon'],
                label: item['label'],
                index: index,
                current: _currentIndex,
                onTap: _onTap,
                avatarUrl: item['avatarUrl'],
              );
            }),
          ),
        ),
      ),
    );
  }

  void _onTap(int index) => setState(() => _currentIndex = index);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      index;
  final int      current;
  final Function(int) onTap;
  final String?  avatarUrl;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;

    // Define specific colors for icons matching Screenshot 1
    Color getIconColor() {
      if (isActive) {
        if (label == 'Durumlar') return const Color(0xFFF59E0B); // Gold/Amber megaphone
        if (label == 'Odalar') return const Color(0xFF10B981); // Green mic
        if (label == 'Mesajlarım') return const Color(0xFF8B5CF6); // Purple bubble
        if (label == 'Ajansım') return const Color(0xFF6366F1); // Indigo building
        return const Color(0xFFEC4899); // Pink/Fuchsia for Keşfet/Profil
      } else {
        if (label == 'Durumlar') return const Color(0xFFEAB308).withOpacity(0.7); // Semi-gold
        if (label == 'Odalar') return const Color(0xFF10B981).withOpacity(0.7); // Semi-green
        if (label == 'Mesajlarım') return const Color(0xFF8B5CF6).withOpacity(0.7); // Semi-purple
        return AppTheme.textSecondary; // Grey
      }
    }

    Widget iconWidget;
    if (label == 'Profil') {
      iconWidget = Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? const Color(0xFFEC4899) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: 11,
          backgroundColor: AppTheme.cardColor,
          backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl!)
              : null,
          child: avatarUrl == null || avatarUrl!.isEmpty
              ? const Icon(Icons.person_rounded, size: 14, color: Colors.white)
              : null,
        ),
      );
    } else {
      iconWidget = Icon(
        icon,
        color: getIconColor(),
        size: 22,
      );
    }

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFEC4899) : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
