import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class LikersScreen extends StatefulWidget {
  const LikersScreen({Key? key}) : super(key: key);

  @override
  State<LikersScreen> createState() => _LikersScreenState();
}

class _LikersScreenState extends State<LikersScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _likers = [];

  @override
  void initState() {
    super.initState();
    _fetchLikers();
  }

  Future<void> _fetchLikers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.getLikers();
      if (mounted) {
        setState(() {
          _likers = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlockLiker(int likeId, String type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Beğeniyi Aç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Bu beğeninin sahibini 10 Kredi karşılığında görmek istiyor musunuz?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Gör', style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await _api.unlockProfileLiker(type, likeId);
      if (res['success'] == true) {
        Provider.of<AuthProvider>(context, listen: false).loadUser();
        _fetchLikers();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        title: const Text('Beğenen Kullanıcılar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _likers.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('❤️', style: TextStyle(fontSize: 50)),
          SizedBox(height: 16),
          Text('Beğeni Bulunmuyor', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Profilinizi veya fotoğraflarınızı henüz beğenen kimse yok.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _likers.length,
      itemBuilder: (context, index) {
        final item = _likers[index];
        final sender = item['sender'];
        if (sender == null) return const SizedBox.shrink();

        final bool isLocked = item['is_locked'] ?? false;
        final String name = sender.name;
        final String? avatarUrl = sender.avatarUrl;
        final String label = item['target_label'] ?? 'Beğendi';
        final String dateStr = item['created_at']?.split('T')?.first ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderCol),
          ),
          child: Row(
            children: [
              // Avatar with conditional blur
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                    child: avatarUrl == null ? const Icon(Icons.person) : null,
                  ),
                  if (isLocked)
                    Positioned.fill(
                      child: ClipOval(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(color: Colors.black38),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLocked ? 'Gizli Üye' : name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLocked ? 'Bir içeriğini beğendi — Kilidi aç' : label,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Action button or date
              if (isLocked)
                ElevatedButton(
                  onPressed: () => _unlockLiker(item['id'] as int, item['type'] as String),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Kilidi Aç', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
            ],
          ),
        );
      },
    );
  }
}
