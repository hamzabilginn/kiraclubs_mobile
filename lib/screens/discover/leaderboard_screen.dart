import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../profile/public_profile_screen.dart';
import '../wallet/wallet_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _leaders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).loadUser();
      final data = await _api.getLeaderboard();
      setState(() {
        _leaders = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sıralama yüklenirken hata oluştu.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _buyPackage(String packageId, int price) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;

    if (auth.user!.tokens < price) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text('Yetersiz Kredi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('Bu VIP paketini satın almak için yeterli krediniz bulunmamaktadır. Kredi yüklemek ister misiniz?', style: TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                ).then((_) => auth.loadUser());
              },
              child: const Text('Kredi Yükle', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text('${packageId.toUpperCase()} VIP Satın Al', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('$price Kredi karşılığında ${packageId.toUpperCase()} VIP üyeliğe geçiş yapmak istiyor musunuz?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Satın Al', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await _api.buyVip(packageId);
      if (res['success'] == true) {
        await auth.loadUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res['message'] ?? 'VIP üyeliğiniz başarıyla aktif edildi!'),
            backgroundColor: Colors.green,
          ));
        }
        _fetchLeaderboard();
      } else {
        throw Exception(res['error'] ?? 'İşlem başarısız.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🏆', style: TextStyle(fontSize: 18)),
            SizedBox(width: 6),
            Text(
              'Sıralama & VIP',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // ⚡ Kredi Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ).then((_) {
                auth.loadUser();
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      '${user?.tokens ?? 0} Kredi',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _fetchLeaderboard,
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildLevelProgressCard(user),
                    _buildVipPackages(user),
                    _buildLeaderboardList(user),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLevelProgressCard(UserModel? user) {
    if (user == null) return const SizedBox.shrink();

    final levelProgressVal = user.levelProgress;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Circular level badge
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFC084FC), Color(0xFFE879F9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${user.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mevcut Seviyeniz: Lvl ${user.level}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sıralama Unvanı: ${user.rankName}',
                      style: const TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'XP SEVİYESİ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '%$levelProgressVal',
                style: const TextStyle(
                  color: Color(0xFFF43F5E),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: levelProgressVal / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFF0F172A),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF43F5E)),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${user.xpPoints} / ${(user.level) * 500} XP',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipPackages(UserModel? user) {
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('💎', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'VIP Paketler',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'VIP üyelik ile kim beğendiğini gör, sıralamada öne çık ve özel rozet kazan!',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildPackageCard(
          title: 'SILVER',
          price: 200,
          originalPrice: '200 TL',
          duration: '30 Gün',
          features: [
            'Kim beğendi — ücretsiz gör',
            'Silver rozet profilde görünür',
            '+500 Bonus XP (Anında Seviye!)',
          ],
          packageId: 'silver',
          user: user,
          gradient: const LinearGradient(
            colors: [Color(0xFF94A3B8), Color(0xFF475569)],
          ),
        ),
        _buildPackageCard(
          title: 'GOLD',
          price: 500,
          originalPrice: '500 TL',
          duration: '30 Gün',
          features: [
            'Tüm Silver avantajları',
            'Gold rozet profilde görünür',
            '+1000 Bonus XP (2 Seviye Birden!)',
            '150 ücretsiz mesaj hakkı / ay',
          ],
          packageId: 'gold',
          user: user,
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          ),
        ),
        _buildPackageCard(
          title: 'PLATINUM',
          price: 1200,
          originalPrice: '1200 TL',
          duration: '30 Gün',
          features: [
            'Tüm Gold avantajları',
            'Gizli profil görüntüleme',
            'Özel Platinum çerçeve',
            '7/24 öncelikli destek',
            '+2000 Bonus XP (4 Seviye Birden!)',
            '350 ücretsiz mesaj hakkı / ay',
          ],
          packageId: 'platinum',
          user: user,
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageCard({
    required String title,
    required int price,
    required String originalPrice,
    required String duration,
    required List<String> features,
    required String packageId,
    required UserModel user,
    required Gradient gradient,
  }) {
    final isUserVip = user.isVip;
    final String currentVip = isUserVip ? (user.vipLevel ?? 'none') : 'none';

    final Map<String, int> weights = {'none': 0, 'silver': 1, 'gold': 2, 'platinum': 3};
    final currentWeight = weights[currentVip] ?? 0;
    final targetWeight = weights[packageId] ?? 0;

    bool isCurrentPackage = isUserVip && currentVip == packageId;
    bool isHigherActive = isUserVip && currentWeight > targetWeight;

    String buttonText = 'Satın Al';
    bool isButtonEnabled = true;

    if (isCurrentPackage) {
      buttonText = 'Üst Seviye Üyelik Aktif';
      isButtonEnabled = false;
    } else if (isHigherActive) {
      buttonText = 'Zaten Üst Üyeliğe Sahipsiniz';
      isButtonEnabled = false;
    } else {
      buttonText = '${title.toUpperCase()} Al';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (packageId == 'gold')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'POPÜLER',
                    style: TextStyle(
                      color: Color(0xFFFBBF24),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$price',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Kredi',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '~$originalPrice',
            style: const TextStyle(
              color: Color(0xFF60A5FA),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            duration,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Text('   ', style: TextStyle(fontSize: 12)),
                    Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981).withOpacity(0.8), size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isButtonEnabled ? () => _buyPackage(packageId, price) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isButtonEnabled ? const Color(0xFF6366F1) : const Color(0xFF334155),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: const Color(0xFF1E293B),
              ),
              child: Text(
                buttonText,
                style: TextStyle(
                  color: isButtonEnabled ? Colors.white : Colors.white30,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(UserModel? currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'En Aktif Kullanıcılar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        _leaders.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _leaders.length,
                itemBuilder: (context, index) {
                  final leader = _leaders[index];
                  final rank = index + 1;
                  return _buildLeaderRow(leader, rank, currentUser);
                },
              ),
      ],
    );
  }

  Widget _buildLeaderRow(Map<String, dynamic> user, int rank, UserModel? currentUser) {
    final String name = user['name'] ?? 'Kullanıcı';
    final String? avatarUrl = user['avatar_url'];
    final int xp = user['xp_points'] as int? ?? 0;
    final int level = user['level'] as int? ?? 1;
    final String? vipLevel = user['vip_level'];

    final bool isMe = currentUser != null && user['id'] == currentUser.id;
    final displayName = isMe ? '$name (Sen)' : name;

    Widget rankBadge;
    if (rank == 1) {
      rankBadge = Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFFEF08A),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🥇', style: TextStyle(fontSize: 16)),
        ),
      );
    } else if (rank == 2) {
      rankBadge = Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFE2E8F0),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🥈', style: TextStyle(fontSize: 16)),
        ),
      );
    } else if (rank == 3) {
      rankBadge = Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFFFEDD5),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('🥉', style: TextStyle(fontSize: 16)),
        ),
      );
    } else {
      rankBadge = Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Text(
          '$rank',
          style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: user['id'])),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.02)),
        ),
        child: Row(
          children: [
            rankBadge,
            const SizedBox(width: 8),
            ClipOval(
              child: SizedBox(
                width: 42,
                height: 42,
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: AppTheme.backgroundColor),
                        errorWidget: (context, url, error) => _podiumPlaceholder(name),
                      )
                    : _podiumPlaceholder(name),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: isMe ? const Color(0xFFF43F5E) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vipLevel != null && vipLevel.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: vipLevel == 'platinum'
                                ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)])
                                : vipLevel == 'gold'
                                    ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                                    : const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF475569)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            vipLevel.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv. $level',
                          style: const TextStyle(color: AppTheme.primaryColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user['rank_name'] ?? 'Derecesiz',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$xp',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  'XP',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Henüz sıralama verisi bulunmuyor.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _podiumPlaceholder(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4C1D95), Color(0xFF831843)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
