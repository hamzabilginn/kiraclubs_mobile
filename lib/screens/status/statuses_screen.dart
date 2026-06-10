import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class StatusesScreen extends StatefulWidget {
  const StatusesScreen({Key? key}) : super(key: key);

  @override
  State<StatusesScreen> createState() => _StatusesScreenState();
}

class _StatusesScreenState extends State<StatusesScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _contentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _statuses = [];
  bool _isLoading = true;
  bool _isSharing = false;
  int _currentPage = 1;
  bool _hasMore = true;
  File? _selectedMedia;

  @override
  void initState() {
    super.initState();
    _fetchStatuses();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatuses({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _statuses = [];
        _hasMore = true;
        _isLoading = true;
      });
    }

    if (!_hasMore) return;

    try {
      final res = await _api.getStatuses(page: _currentPage);
      final List<dynamic> newItems = res['statuses'] ?? [];
      final int lastPage = res['last_page'] ?? 1;

      setState(() {
        _statuses.addAll(newItems);
        _isLoading = false;
        _hasMore = _currentPage < lastPage;
        if (_hasMore) _currentPage++;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchStatuses();
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() {
        _selectedMedia = File(file.path);
      });
    }
  }

  Future<void> _shareStatus() async {
    final text = _contentController.text.trim();
    if (text.isEmpty && _selectedMedia == null) return;

    setState(() => _isSharing = true);

    try {
      await _api.createStatus(
        content: text,
        mediaPath: _selectedMedia?.path,
      );
      
      _contentController.clear();
      setState(() {
        _selectedMedia = null;
        _isSharing = false;
      });

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Durum başarıyla paylaşıldı! ✅'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }

      _fetchStatuses(refresh: true);
    } catch (e) {
      setState(() => _isSharing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Paylaşım başarısız oldu.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _toggleLike(int index) async {
    final status = _statuses[index];
    final int statusId = status['id'];
    
    // Optimistic update
    setState(() {
      status['is_liked'] = !status['is_liked'];
      status['likes_count'] = status['is_liked'] 
          ? (status['likes_count'] ?? 0) + 1 
          : (status['likes_count'] ?? 1) - 1;
    });

    try {
      await _api.likeStatus(statusId);
    } catch (e) {
      // Revert if failed
      setState(() {
        status['is_liked'] = !status['is_liked'];
        status['likes_count'] = status['is_liked'] 
            ? (status['likes_count'] ?? 0) + 1 
            : (status['likes_count'] ?? 1) - 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: AppTheme.accentColor, size: 28),
            const SizedBox(width: 8),
            ShaderMask(
              shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
              child: const Text(
                'Durumlar',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchStatuses(refresh: true),
        color: AppTheme.primaryColor,
        backgroundColor: AppTheme.cardColor,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildShareBox(),
              _isLoading && _statuses.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _statuses.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(Icons.campaign_outlined, size: 48, color: AppTheme.textSecondary),
                                const SizedBox(height: 12),
                                Text('Henüz paylaşılmış bir durum yok.', 
                                    style: TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _statuses.length,
                          itemBuilder: (context, index) => _buildStatusCard(index),
                        ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareBox() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✍️ Ne düşünüyorsun?', 
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ne düşünüyorsun?...',
              fillColor: Color(0xFF0C0A10),
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedMedia != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedMedia!, height: 120, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMedia = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickMedia,
              icon: const Text('📸/📹', style: TextStyle(fontSize: 14)),
              label: const Text('Fotoğraf/Video Yükle', style: TextStyle(fontSize: 12, color: Colors.white)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF1F1D2C),
                side: const BorderSide(color: AppTheme.borderCol),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _isSharing
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _shareStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Paylaş', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(int index) {
    final status = _statuses[index];
    final user = status['user'] ?? {};
    final String name = user['name'] ?? 'Kullanıcı';
    final String? avatarUrl = user['avatar_url'];
    final bool isVip = user['is_vip'] ?? false;
    final bool isVerified = user['verification_status'] == 'approved';
    final String content = status['content'] ?? '';
    final String? mediaUrl = status['media_url'];
    final String timeStr = '1 saat önce'; // Dynamic timeline simplified or parsed
    final bool isLiked = status['is_liked'] ?? false;
    final int likesCount = status['likes_count'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.backgroundColor,
                backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 10),
                          ),
                        ],
                        const SizedBox(width: 4),
                        const Text('🇹🇷', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(timeStr, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
          if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(height: 200, color: AppTheme.backgroundColor, child: const Center(child: CircularProgressIndicator())),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleLike(index),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? Colors.red : AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text('$likesCount', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 6),
              Text('${status['comments_count'] ?? 0}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              Icon(Icons.visibility_outlined, color: AppTheme.textSecondary, size: 18),
              const SizedBox(width: 6),
              Text('${status['views_count'] ?? 0}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
