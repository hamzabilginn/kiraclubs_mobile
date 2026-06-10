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

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({Key? key}) : super(key: key);

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

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
