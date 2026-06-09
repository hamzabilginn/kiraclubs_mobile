import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final ApiService _api = ApiService();

  Map<String, dynamic> _wallet = {'tokens': 0, 'earned_coins': 0, 'transactions': []};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadWallet();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    try {
      final w = await _api.getWallet();
      setState(() { _wallet = w; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _wallet['tokens'] as int? ?? 0;
    final earned = _wallet['earned_coins'] as int? ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(child: Column(children: [
        _header(),
        _balanceCard(tokens, earned),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [Tab(text: 'Jeton Al'), Tab(text: 'VIP')],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : TabBarView(controller: _tabCtrl, children: [
                  _tokenTab(),
                  _vipTab(),
                ]),
        ),
      ])),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      const Text('Cüzdan',
        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      const Spacer(),
      IconButton(icon: Icon(Icons.history_rounded, color: AppTheme.textSecondary), onPressed: () {}),
    ]),
  );

  Widget _balanceCard(int tokens, int earned) => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.35),
        blurRadius: 24, spreadRadius: 2)]),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bakiye', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text('$tokens Jeton',
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      ])),
      Container(width: 1, height: 50, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 20)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Kazanç', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text('$earned Coin',
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      ])),
    ]),
  );

  Widget _tokenTab() {
    const packages = [
      {'label': '100 Jeton',   'icon': '🪙', 'price': '₺29'},
      {'label': '300 Jeton',   'icon': '💎', 'price': '₺79'},
      {'label': '600 Jeton',   'icon': '💎', 'price': '₺149'},
      {'label': '1500 Jeton',  'icon': '👑', 'price': '₺349'},
      {'label': '3000 Jeton',  'icon': '👑', 'price': '₺649'},
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 8),
      ...packages.map((p) => _tokenCard(
        label: p['label']!, icon: p['icon']!, price: p['price']!,
        onTap: () => _showComingSoon())),
    ]);
  }

  Widget _tokenCard({required String label, required String icon,
    required String price, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cardColor, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderCol)),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Expanded(child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(12)),
            child: Text(price,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        ]),
      ),
    );
  }

  Widget _vipTab() {
    final vips = [
      {'label': 'Silver VIP', 'emoji': '⭐', 'color': 0xFF94A3B8, 'price': '₺149/ay',
        'perks': ['Kim beğendi gör', 'Özel çerçeve', 'VIP Rozeti']},
      {'label': 'Gold VIP', 'emoji': '🌟', 'color': 0xFFFFB800, 'price': '₺249/ay',
        'perks': ['Silver avantajları', 'Sınırsız mesaj', 'Profil öne çıkma']},
      {'label': 'Platinum VIP', 'emoji': '💎', 'color': 0xFF8B5CF6, 'price': '₺449/ay',
        'perks': ['Tüm avantajlar', 'Öncelikli destek', 'Özel rozet']},
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 8),
      ...vips.map((v) => _vipCard(
        label: v['label'] as String, emoji: v['emoji'] as String,
        color: Color(v['color'] as int), price: v['price'] as String,
        perks: (v['perks'] as List).cast<String>(),
        onTap: () => _showComingSoon())),
    ]);
  }

  Widget _vipCard({required String label, required String emoji,
    required Color color, required String price, required List<String> perks,
    required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(child: Text(label,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3))),
              child: Text(price, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))),
          ]),
          const SizedBox(height: 16),
          ...perks.map((p) => Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Text(p, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ]))),
        ]),
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Google Play ödeme sistemi yakında aktif olacak! 🚀'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
