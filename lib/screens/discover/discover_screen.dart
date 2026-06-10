import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../profile/public_profile_screen.dart';
import '../chat/chat_screen.dart';
import 'leaderboard_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({Key? key}) : super(key: key);

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<UserModel> _users = [];
  List<Map<String, dynamic>> _countries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _lastPage = 1;
  bool _hasMore = false;

  // Active Filters
  String _searchQuery = '';
  bool _filterOnline = false;
  bool _filterHasMedia = false;
  bool _filterVerified = false;
  bool _filterNewest = false;
  String? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _refreshUsers();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreUsers();
    }
  }

  Future<void> _refreshUsers() async {
    if (mounted) setState(() => _isLoading = true);
    _currentPage = 1;
    await _loadUsers(1);
  }

  Future<void> _loadUsers(int page) async {
    try {
      final result = await _api.getDiscover(
        page: page,
        search: _searchQuery,
        online: _filterOnline,
        hasMedia: _filterHasMedia,
        verified: _filterVerified,
        country: _selectedCountry,
        newest: _filterNewest,
      );

      final List<UserModel> loadedUsers = result['profiles'] as List<UserModel>;
      final List<Map<String, dynamic>> loadedCountries = 
          (result['countries'] as List<dynamic>).cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          if (page == 1) {
            _users = loadedUsers;
          } else {
            _users.addAll(loadedUsers);
          }
          _countries = loadedCountries;
          _currentPage = result['current_page'] as int;
          _lastPage = result['last_page'] as int;
          _hasMore = _currentPage < _lastPage;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);
    await _loadUsers(_currentPage + 1);
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.trim();
      });
      _refreshUsers();
    });
  }

  String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '📍';
    final int firstLetter = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  void _resetAllFilters() {
    setState(() {
      _filterOnline = false;
      _filterHasMedia = false;
      _filterVerified = false;
      _filterNewest = false;
      _selectedCountry = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _refreshUsers();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveFilter = _filterOnline ||
        _filterHasMedia ||
        _filterVerified ||
        _filterNewest ||
        _selectedCountry != null ||
        _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header
            SliverToBoxAdapter(child: _header()),

            // Search Bar
            SliverToBoxAdapter(child: _searchBar()),

            // Filter Pills Row
            SliverToBoxAdapter(child: _filterPills(hasActiveFilter)),

            // Users Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: _isLoading
                  ? _shimmerGrid()
                  : _users.isEmpty
                      ? SliverFillRemaining(hasScrollBody: false, child: _emptyState())
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.61, // Aspect ratio to comfortably fit 3/4 photo + action buttons
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _userCard(_users[index]),
                            childCount: _users.length,
                          ),
                        ),
            ),

            // Pagination loading indicator or end message
            if (!_isLoading && _users.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: _isLoadingMore
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(
                            _hasMore ? '' : 'Tüm profiller yüklendi.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
              child: const Text(
                'KiraClubs',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const Spacer(),
            // Leaderboard Button
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderCol),
              ),
              child: IconButton(
                icon: const Icon(Icons.emoji_events_rounded, color: Colors.amber),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                  );
                },
                tooltip: 'Sıralama',
              ),
            ),
            const SizedBox(width: 8),
            // Refresh Button
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderCol),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _refreshUsers,
                tooltip: 'Yenile',
              ),
            ),
          ],
        ),
      );

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Kullanıcı adı ile ara...',
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
        ),
      );

  Widget _filterPills(bool hasActiveFilter) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Clear Filters Pill (Visible only when filters are active)
          if (hasActiveFilter)
            _pill(
              label: 'Temizle ❌',
              isActive: false,
              onTap: _resetAllFilters,
              color: Colors.red.withOpacity(0.15),
              borderColor: Colors.red.withOpacity(0.3),
            ),

          // Tümü (All)
          _pill(
            label: 'Tümü',
            isActive: !hasActiveFilter,
            onTap: _resetAllFilters,
          ),

          // Onaylı Profiller (Verified)
          _pill(
            label: '🛡️ Onaylı',
            isActive: _filterVerified,
            onTap: () {
              setState(() => _filterVerified = !_filterVerified);
              _refreshUsers();
            },
            activeColor: const Color(0xFF2563EB),
          ),

          // Şu an Çevrimiçi (Online)
          _pill(
            label: '🟢 Çevrimiçi',
            isActive: _filterOnline,
            onTap: () {
              setState(() => _filterOnline = !_filterOnline);
              _refreshUsers();
            },
            activeColor: const Color(0xFF10B981),
          ),

          // Fotoğraflı Profiller (With Media)
          _pill(
            label: '📸 Fotoğraflı',
            isActive: _filterHasMedia,
            onTap: () {
              setState(() => _filterHasMedia = !_filterHasMedia);
              _refreshUsers();
            },
            activeColor: const Color(0xFFEC4899),
          ),

          // Yeni Katılanlar (Newest)
          _pill(
            label: '✨ Yeni',
            isActive: _filterNewest,
            onTap: () {
              setState(() => _filterNewest = !_filterNewest);
              _refreshUsers();
            },
            activeColor: AppTheme.primaryColor,
          ),

          // Divider
          if (_countries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Container(width: 1, height: 20, color: AppTheme.borderCol),
              ),
            ),

          // Country Pills
          ..._countries.map((c) {
            final String code = c['code'] as String;
            final String name = c['name'] as String;
            final int total = c['total'] as int;
            final bool isSelected = _selectedCountry == code;

            return _pill(
              label: '$name ($total)',
              isActive: isSelected,
              onTap: () {
                setState(() {
                  _selectedCountry = isSelected ? null : code;
                });
                _refreshUsers();
              },
              activeColor: const Color(0xFF4F46E5),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color? activeColor,
    Color? color,
    Color? borderColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? (activeColor ?? AppTheme.primaryColor)
                : (color ?? AppTheme.cardColor),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? Colors.transparent
                  : (borderColor ?? AppTheme.borderCol),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _userCard(UserModel user) {
    final bool isOnline = user.isOnline;
    final bool isVip = user.isVip;
    final String? vipLevel = user.vipLevel;

    // VIP Gradients
    Gradient? vipGradient;
    if (isVip && vipLevel != null) {
      if (vipLevel == 'silver') {
        vipGradient = const LinearGradient(
          colors: [Color(0xFF94A3B8), Color(0xFFF1F5F9), Color(0xFF475569)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else if (vipLevel == 'gold') {
        vipGradient = const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFFEF08A), Color(0xFFD97706), Color(0xFFFBBF24)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      } else if (vipLevel == 'platinum') {
        vipGradient = const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF3B82F6), Color(0xFFD946EF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      }
    }

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Media / Photo area (aspect ratio 3/4)
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  // Photo Swiper or Image
                  Positioned.fill(
                    child: user.media.isNotEmpty
                        ? PageView.builder(
                            itemCount: user.media.length,
                            itemBuilder: (context, index) {
                              final media = user.media[index];
                              if (media.type == 'photo' || media.type == 'image') {
                                return CachedNetworkImage(
                                  imageUrl: media.url,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppTheme.backgroundColor,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => _avatarPlaceholder(user.name),
                                );
                              } else {
                                // Video
                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: user.avatarUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: user.avatarUrl!,
                                              fit: BoxFit.cover,
                                              errorWidget: (context, url, error) => _avatarPlaceholder(user.name),
                                            )
                                          : _avatarPlaceholder(user.name),
                                    ),
                                    // Play overlay
                                    Container(
                                      color: Colors.black26,
                                      child: const Center(
                                        child: Icon(
                                          Icons.play_circle_outline_rounded,
                                          color: Colors.white,
                                          size: 44,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          )
                        : (user.avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: user.avatarUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => _avatarPlaceholder(user.name),
                              )
                            : _avatarPlaceholder(user.name)),
                  ),

                  // Swiper indicator dots
                  if (user.media.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          user.media.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Card gradient overlay
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.85),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Verification & Online Status
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (user.verificationStatus == 'verified')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(1.5),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Color(0xFF2563EB),
                                    size: 8,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Onaylı',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isOnline) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF34D399),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else if (isOnline)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF34D399),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.cardColor, width: 2),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // VIP badge
                  if (isVip && vipLevel != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: vipLevel == 'platinum'
                              ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)])
                              : vipLevel == 'gold'
                                  ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                                  : const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF475569)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${vipLevel.toUpperCase()} VIP',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // User Info Overlay
                  Positioned(
                    bottom: 8,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVip) ...[
                              const SizedBox(width: 2),
                              Text(
                                vipLevel == 'platinum' ? '💎' : vipLevel == 'gold' ? '👑' : '🥈',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📍 ${_getFlagEmoji(user.country ?? 'TR')} ${user.country ?? 'TR'}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Send Message Action Button
          Padding(
            padding: const EdgeInsets.all(8),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(partner: user),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Mesaj Gönder',
                      style: TextStyle(
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
    );

    // If VIP, wrap in gradient border container
    if (isVip && vipGradient != null) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicProfileScreen(userId: user.id),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            gradient: vipGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: (vipLevel == 'platinum'
                        ? const Color(0xFF8B5CF6)
                        : vipLevel == 'gold'
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF94A3B8))
                    .withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: cardContent,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicProfileScreen(userId: user.id),
        ),
      ),
      child: cardContent,
    );
  }

  Widget _avatarPlaceholder(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4C1D95), Color(0xFF831843)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '👤',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _shimmerGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.61,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => Shimmer.fromColors(
          baseColor: AppTheme.cardColor,
          highlightColor: const Color(0xFF2A2740),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        childCount: 6,
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore_off_rounded, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Sonuç bulunamadı!',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı bir arama veya filtre deneyin.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _resetAllFilters,
            child: const Text('Filtreleri Temizle'),
          ),
        ],
      ),
    );
  }
}
