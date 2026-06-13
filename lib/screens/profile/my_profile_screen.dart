import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'agency_screen.dart';
import 'support_tickets_screen.dart';
import 'visitors_screen.dart';
import 'likers_screen.dart';
import 'public_profile_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({Key? key}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  
  bool _isLoading = true;
  bool _isSaving = false;
  UserModel? _user;
  Map<String, dynamic> _dailyTasks = {};
  
  // Controllers & Form State
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _agencyInviteController = TextEditingController();
  bool _isIncognito = false;
  bool _notificationsOn = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _agencyInviteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final data = await _api.getMeWithTasks();
      if (mounted) {
        setState(() {
          _user = data['user'] as UserModel;
          _dailyTasks = data['daily_tasks'] as Map<String, dynamic>? ?? {};
          _nameController.text = _user?.name ?? '';
          _bioController.text = _user?.bio ?? '';
          _isIncognito = _user?.isIncognito ?? false;
          _isLoading = false;
        });
        // Update AuthProvider state
        Provider.of<AuthProvider>(context, listen: false).updateUser(_user!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showToast('Hata: $e', isError: true);
      }
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveChanges() async {
    final nameText = _nameController.text.trim();
    if (nameText.isEmpty) {
      _showToast('İsim alanı boş bırakılamaz!', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final updatedUser = await _api.updateProfile(
        name: nameText,
        bio: _bioController.text.trim(),
        isIncognito: _isIncognito,
      );
      Provider.of<AuthProvider>(context, listen: false).updateUser(updatedUser);
      setState(() {
        _user = updatedUser;
        _isSaving = false;
      });
      _showToast('Değişiklikler başarıyla kaydedildi!');
    } catch (e) {
      setState(() => _isSaving = false);
      _showToast('Hata: $e', isError: true);
    }
  }

  Future<void> _uploadPhoto(String type) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (img == null) return;

    setState(() => _isLoading = true);
    try {
      await _api.uploadMedia(img.path, type);
      await _loadProfileData();
      _showToast('Medya başarıyla yüklendi!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast('Medya yüklenemedi: $e', isError: true);
    }
  }

  Future<void> _deletePhoto(int mediaId) async {
    setState(() => _isLoading = true);
    try {
      await _api.deleteMedia(mediaId);
      await _loadProfileData();
      _showToast('Medya başarıyla silindi!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast('Medya silinemedi: $e', isError: true);
    }
  }

  Future<void> _uploadVerificationPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (img == null) return;

    setState(() => _isLoading = true);
    try {
      final res = await _api.uploadVerificationPhoto(img.path);
      if (res['success'] == true) {
        _showToast(res['message'] ?? 'Fotoğraf başarıyla yüklendi!');
        await _loadProfileData();
      } else {
        _showToast(res['message'] ?? 'Fotoğraf yüklenemedi.', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast('Yükleme hatası: $e', isError: true);
    }
  }

  Future<void> _joinAgency() async {
    final code = _agencyInviteController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await _api.joinAgency(code);
      _agencyInviteController.clear();
      _showToast(res['message'] ?? 'Ajansa başarıyla katıldınız!');
      await _loadProfileData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast('Hata: $e', isError: true);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Çıkış Yap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  Widget _buildLeaderboardRankBadge(int? rank) {
    if (rank == null) return const SizedBox.shrink();

    Gradient? grad;
    Color borderCol = Colors.transparent;
    String label = '';
    List<BoxShadow> shadow = [];

    if (rank <= 10) {
      label = '👑 #$rank';
      grad = const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF8B5CF6)]);
      borderCol = const Color(0xFFFBBF24).withOpacity(0.5);
      shadow = [
        BoxShadow(
          color: const Color(0xFFF59E0B).withOpacity(0.4),
          blurRadius: 10,
          spreadRadius: 1,
        )
      ];
    } else if (rank <= 50) {
      label = '🏆 #$rank';
      grad = const LinearGradient(colors: [Color(0xFF22D3EE), Color(0xFF2563EB)]);
      borderCol = const Color(0xFF22D3EE).withOpacity(0.3);
      shadow = [
        BoxShadow(
          color: const Color(0xFF22D3EE).withOpacity(0.2),
          blurRadius: 8,
        )
      ];
    } else if (rank <= 100) {
      label = '✨ #$rank';
      grad = const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]);
      borderCol = const Color(0xFF6366F1).withOpacity(0.2);
    } else {
      label = '#$rank';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: shadow,
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0D1A),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0D1A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          title: const Text('Profil', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Profil Yüklenemedi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Profil bilgileri sunucudan alınamadı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin veya yeniden giriş yapın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadProfileData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Yeniden Dene'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    await auth.logout();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: const Text('Çıkış Yap', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = _user!;
    final referralCode = user.referralCode ?? 'KIRA${user.id}';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        centerTitle: true,
        leadingWidth: 120,
        leading: TextButton.icon(
          onPressed: () {
            // Focus discover page (tab index 0) or simple pop if navigation sub-page
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white54),
          label: const Text('Keşfet\'e Dön', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (user.leaderboardRank != null) ...[
              const SizedBox(width: 6),
              _buildLeaderboardRankBadge(user.leaderboardRank),
            ],
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2))),
                  )
                : TextButton(
                    onPressed: _saveChanges,
                    child: const Text(
                      'Kaydet',
                      style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFEF4444),
          indicatorWeight: 3,
          labelColor: const Color(0xFFEF4444),
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          onTap: (index) {
            setState(() {}); // refresh actions based on tab
          },
          tabs: const [
            Tab(text: 'Düzenle'),
            Tab(text: 'Ön İzleme'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditTab(user, referralCode),
          PublicProfileScreen(userId: user.id), // Live public profile preview
        ],
      ),
    );
  }

  Widget _buildEditTab(UserModel user, String referralCode) {
    final isFemale = user.gender == 'female';

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      color: AppTheme.primaryColor,
      backgroundColor: const Color(0xFF1E293B),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media grid section
            _buildMediaGridSection(user),
            const SizedBox(height: 20),

            // Referral code card
            _buildReferralCard(referralCode),
            const SizedBox(height: 16),



            // Daily Tasks section (female only)
            if (isFemale) ...[
              _buildDailyTasksSection(),
              const SizedBox(height: 20),
            ],

            // About me section
            _buildAboutMeSection(),
            const SizedBox(height: 20),

            // Incognito toggle card
            _buildIncognitoCard(user),
            const SizedBox(height: 16),

            // Push notifications card
            _buildNotificationsCard(),
            const SizedBox(height: 16),

            // Verification (Mavi Tik) card
            _buildVerificationCard(user),
            const SizedBox(height: 16),

            // Agency system card (female only)
            if (isFemale) ...[
              _buildAgencySection(user),
              const SizedBox(height: 16),
            ],

            // Agency management redirect
            if (user.isAgencyOwner) ...[
              _buildAgencyGoToButton(),
              const SizedBox(height: 16),
            ],

            // Support card
            _buildSupportCard(),
            const SizedBox(height: 24),

            // Logout
            _buildLogoutButton(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGridSection(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MEDYALARIM',
          style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        const Text(
          'En fazla 9 fotoğraf ekle. Kişiliğini paylaşmak için ipuçlarını kullan. Fotoğraf ipuçlarımızla ön plana çık',
          style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75, // Aspect ratio matching 3:4 aspect-[3/4] on web
          ),
          itemCount: 9,
          itemBuilder: (ctx, index) {
            if (index < user.media.length) {
              final mediaItem = user.media[index];
              final isVideo = mediaItem.type == 'video';
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Stack(
                  children: [
                    // Media Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: mediaItem.url,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white30)),
                      ),
                    ),

                    // Play icon for video
                    if (isVideo)
                      const Center(
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black45,
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                        ),
                      ),

                    // Delete Button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => _deletePhoto(mediaItem.id),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return GestureDetector(
                onTap: () {
                  // Show option dialog for image or video
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1E293B),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.image_rounded, color: Colors.white),
                            title: const Text('Fotoğraf Yükle', style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _uploadPhoto('photo');
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.video_library_rounded, color: Colors.white),
                            title: const Text('Video Yükle', style: TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _uploadPhoto('video');
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: CustomPaint(
                  painter: DashedBorderPainter(
                    color: Colors.white24,
                    borderRadius: 14,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        '+',
                        style: TextStyle(color: Colors.white38, fontSize: 28, fontWeight: FontWeight.w300),
                      ),
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildReferralCard(String code) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text('🎁 ', style: TextStyle(fontSize: 14)),
                    Text(
                      'Referans Kodun',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Arkadaşlarını davet et — Mavi Tik alınca ikiniz de 10 Kredi kazanın! 🔵',
                  style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0D1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      _showToast('Referans kodu kopyalandı! 📋');
                    },
                    child: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      final shareLink = 'https://kiraclubs.com/register?ref=$code';
                      Clipboard.setData(ClipboardData(text: shareLink));
                      _showToast('Paylaşım linki kopyalandı! 🔗');
                    },
                    child: const Icon(Icons.share_rounded, color: Colors.white70, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDailyTasksSection() {
    final bool isMsgCompleted = _dailyTasks['send_message'] == true;
    final bool isStatusCompleted = _dailyTasks['share_status'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎯 Günlük Görevler',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Günlük görevleri tamamlayarak ekstra kredi kazanabilirsiniz.',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 16),
          
          // Task 1: Send message
          _buildTaskRow(
            icon: '💬',
            title: 'Mesaj Gönder',
            reward: '+2.50 Kredi',
            isCompleted: isMsgCompleted,
            onAction: () {
              _showToast('Keşfet veya Mesajlar sekmesinden bir kullanıcıya mesaj göndererek görevi tamamlayabilirsiniz! 💬');
            },
          ),
          const SizedBox(height: 10),

          // Task 2: Share status
          _buildTaskRow(
            icon: '📣',
            title: 'Durum Paylaş',
            reward: '+2.50 Kredi',
            isCompleted: isStatusCompleted,
            onAction: () {
              _showToast('Durumlar sekmesinden yeni bir durum paylaşarak görevi tamamlayabilirsiniz! 📣');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow({
    required String icon,
    required String title,
    required String reward,
    required bool isCompleted,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0D1A).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 2),
                Text(reward, style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 12),
                  SizedBox(width: 4),
                  Text('Tamamlandı', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Yap', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildAboutMeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AD SOYAD',
          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          maxLength: 50,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Adınız ve soyadınız...',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF1E293B).withOpacity(0.3),
            counterStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: const Color(0xFF6366F1)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'HAKKIMDA',
          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _bioController,
          maxLines: 4,
          maxLength: 500,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Kendinden bahset...',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF1E293B).withOpacity(0.3),
            counterStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: const Color(0xFF6366F1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncognitoCard(UserModel user) {
    final isVipGoldOrPlatinum = (user.vipLevel == 'gold' || user.vipLevel == 'platinum') && user.isVip;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Text('🕵️ ', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Gizli Profil Modu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('VIP GOLD/PLATINUM', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Discover (Keşfet) sayfasında görünmez olursunuz. Ancak diğer profilleri gezebilir, mesajlaşabilirsiniz.',
                  style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.3),
                ),
              ],
            ),
          ),
          Switch(
            value: _isIncognito,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF6366F1),
            inactiveTrackColor: Colors.white12,
            onChanged: (val) {
              if (isVipGoldOrPlatinum) {
                setState(() => _isIncognito = val);
              } else {
                _showToast('Gizli profil modu sadece GOLD/PLATINUM VIP üyeler içindir.', isError: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Text('🔔 ', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bildirimler Açık', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text(
                  'Mesaj ve arama bildirimlerini anında almak için bildirimleri açın.',
                  style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.3),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _notificationsOn = !_notificationsOn),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _notificationsOn ? const Color(0xFF064E3B) : const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(10),
                border: _notificationsOn ? null : Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  if (_notificationsOn) const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _notificationsOn ? 'Açık' : 'Kapalı',
                    style: TextStyle(color: _notificationsOn ? const Color(0xFF10B981) : Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(UserModel user) {
    final status = user.verificationStatus ?? '';
    final isVerified = status == 'approved' || status == 'verified';
    final isPending = status == 'pending';

    Color cardBg = const Color(0xFF1E293B).withOpacity(0.3);
    Color borderCol = Colors.white.withOpacity(0.05);
    Color iconBg = const Color(0xFF1F2937);
    IconData icon = Icons.check_rounded;
    String title = 'Doğrulanmamış Profil';
    String description = 'Profilinizi doğrulayarak Mavi Tik sahibi olun.';
    Color titleColor = Colors.white;

    if (isVerified) {
      cardBg = const Color(0xFF0F1E36);
      borderCol = const Color(0xFF1D4ED8).withOpacity(0.5);
      iconBg = const Color(0xFF3B82F6);
      title = 'Profiliniz Doğrulandı';
      description = 'Tebrikler! Mavi Tik rozetiniz profilinizde aktif olarak gösterilmektedir.';
      titleColor = const Color(0xFF60A5FA);
    } else if (isPending) {
      cardBg = const Color(0xFF1E1E2C);
      borderCol = Colors.amber.withOpacity(0.3);
      iconBg = Colors.amber;
      icon = Icons.hourglass_empty_rounded;
      title = 'Doğrulama Bekleniyor';
      description = 'Doğrulama fotoğrafınız yüklendi ve incelenmektedir.';
      titleColor = Colors.amber;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mavi Tik (Profil Doğrulama)',
          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                    child: Icon(icon, color: isPending ? Colors.black : Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(description, style: TextStyle(color: isVerified ? const Color(0xFF93C5FD) : Colors.white54, fontSize: 11, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isVerified && !isPending) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _uploadVerificationPhoto,
                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                    label: const Text('Doğrulama Fotoğrafı Gönder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildAgencySection(UserModel user) {
    final hasAgency = user.agencyName != null && user.agencyName!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏢 Ajans Sistemi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          if (hasAgency) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
              ),
              child: Text(
                'Ajans Üyesi: ${user.agencyName}\n🔒 Ajanstan çıkışa izin verilmiyor.',
                style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, height: 1.4, fontWeight: FontWeight.bold),
              ),
            ),
          ] else ...[
            const Text(
              'Bir ajansa katılarak yayıncılık yapabilir ve kazanç elde edebilirsiniz.',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _agencyInviteController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Ajans davet kodu girin',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF0F0D1A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF6366F1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _joinAgency,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Katıl', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAgencyGoToButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AgencyScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏢 ', style: TextStyle(fontSize: 16)),
            Text(
              'Ajans Yönetim Paneline Git →',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SupportTicketsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF2E1065),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.headphones_rounded, color: Color(0xFFC084FC), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Destek Taleplerim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 2),
                  Text('Bir sorun mu yaşıyorsunuz? Destek ekibimize ulaşın.', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF451A23),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.1)),
      ),
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🚪 ', style: TextStyle(fontSize: 16)),
            Text(
              'Çıkış',
              style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedBorderPainter({
    this.color = const Color(0xFF2D2A3A),
    this.strokeWidth = 1.5,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.borderRadius = 14.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    for (final pathMetric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashLength),
          Offset.zero,
        );
        distance += dashLength + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
