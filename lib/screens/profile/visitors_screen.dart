import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class VisitorsScreen extends StatefulWidget {
  const VisitorsScreen({Key? key}) : super(key: key);

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _visitors = [];

  @override
  void initState() {
    super.initState();
    _fetchVisitors();
  }

  Future<void> _fetchVisitors() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.getVisitors();
      if (mounted) {
        setState(() {
          _visitors = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlockVisitor(int viewerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Ziyaretçi Kilidini Aç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Bu ziyaretçinin profilini 10 Kredi karşılığında açmak istiyor musunuz?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Kilidi Aç', style: TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await _api.unlockProfileVisitor(viewerId);
      if (res['success'] == true) {
        // Refresh balance in auth provider
        Provider.of<AuthProvider>(context, listen: false).loadUser();
        _fetchVisitors();
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
        title: const Text('Profil Ziyaretçileri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _visitors.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🕵️', style: TextStyle(fontSize: 50)),
          SizedBox(height: 16),
          Text('Ziyaretçi Bulunmuyor', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Profilinizi henüz ziyaret eden kimse yok.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _visitors.length,
      itemBuilder: (context, index) {
        final visitor = _visitors[index];
        final viewer = visitor['viewer'];
        if (viewer == null) return const SizedBox.shrink();

        final bool isLocked = visitor['is_locked'] ?? false;
        final String name = viewer.name;
        final String? avatarUrl = viewer.avatarUrl;
        final String dateStr = visitor['updated_at']?.split('T')?.first ?? '';

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
                      isLocked ? 'Ziyaret etti — Kilidi aç' : viewer.bio ?? 'KiraClubs Üyesi',
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
                  onPressed: () => _unlockVisitor(viewer.id),
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
