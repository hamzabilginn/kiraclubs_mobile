import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../discover/discover_screen.dart';
import '../chat/inbox_screen.dart';
import '../profile/my_profile_screen.dart';
import '../wallet/wallet_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({Key? key}) : super(key: key);

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DiscoverScreen(),
    InboxScreen(),
    MyProfileScreen(),
    WalletScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.explore_rounded,  label: 'Keşfet',  index: 0, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.chat_bubble_rounded, label: 'Mesajlar', index: 1, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.person_rounded,   label: 'Profil',  index: 2, current: _currentIndex, onTap: _onTap),
              _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Cüzdan', index: 3, current: _currentIndex, onTap: _onTap),
            ],
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

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
              )
            : null,
        child: isActive
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ])
            : Icon(icon, color: AppTheme.textSecondary, size: 24),
      ),
    );
  }
}
