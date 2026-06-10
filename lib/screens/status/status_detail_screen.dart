import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class StatusDetailScreen extends StatefulWidget {
  final Map<String, dynamic> status;

  const StatusDetailScreen({Key? key, required this.status}) : super(key: key);

  @override
  State<StatusDetailScreen> createState() => _StatusDetailScreenState();
}

class _StatusDetailScreenState extends State<StatusDetailScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _comments = [];
  bool _isLoadingComments = true;
  bool _isLiked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.status['is_liked'] ?? false;
    _likesCount = widget.status['likes_count'] ?? 0;
    _loadComments();
    _recordView();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _recordView() async {
    try {
      await _api.viewStatus(widget.status['id'] as int);
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    try {
      final list = await _api.getStatusComments(widget.status['id'] as int);
      if (mounted) {
        setState(() {
          _comments = list;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingComments = false);
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    FocusScope.of(context).unfocus();

    try {
      final res = await _api.postStatusComment(widget.status['id'] as int, text);
      if (res['success'] == true) {
        _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Yorumunuz gönderildi! 💬'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount = _isLiked ? _likesCount + 1 : _likesCount - 1;
    });

    try {
      await _api.likeStatus(widget.status['id'] as int);
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likesCount = _isLiked ? _likesCount + 1 : _likesCount - 1;
      });
    }
  }

  void _showViewersModal() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF151324),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Görüntüleyen Kullanıcılar', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _api.getStatusViewers(widget.status['id'] as int),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }
                  final viewers = snapshot.data ?? [];
                  if (viewers.isEmpty) {
                    return const Center(child: Text('Henüz görüntüleyen kimse yok.', style: TextStyle(color: AppTheme.textSecondary)));
                  }
                  return ListView.builder(
                    itemCount: viewers.length,
                    itemBuilder: (context, index) {
                      final viewer = viewers[index]['user'] ?? viewers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: viewer['avatar_url'] != null ? CachedNetworkImageProvider(viewer['avatar_url']) : null,
                          child: viewer['avatar_url'] == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(viewer['name'] ?? 'Kullanıcı', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(viewer['bio'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.user?.id;
    final statusUser = widget.status['user'] ?? {};
    final bool isMyStatus = currentUserId != null && statusUser['id'] == currentUserId;

    final String name = statusUser['name'] ?? 'Kullanıcı';
    final String? avatarUrl = statusUser['avatar_url'];
    final bool isVerified = statusUser['verification_status'] == 'approved';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        title: const Text('Durum Detayı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (isMyStatus)
            IconButton(
              icon: const Icon(Icons.visibility_outlined, color: Colors.white70),
              onPressed: _showViewersModal,
              tooltip: 'Görüntüleyenler',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Author
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.cardColor,
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
                                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                if (isVerified) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 8),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('1 saat önce', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content text
                  Text(widget.status['content'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
                  const SizedBox(height: 12),

                  // Content Media (image)
                  if (widget.status['media_url'] != null && (widget.status['media_url'] as String).isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: widget.status['media_url'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(height: 200, color: AppTheme.cardColor, child: const Center(child: CircularProgressIndicator())),
                        errorWidget: (context, url, error) => const SizedBox.shrink(),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Action Row (Like & Comment stats)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: _isLiked ? Colors.red.withOpacity(0.1) : AppTheme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: _isLiked ? Colors.red.withOpacity(0.3) : AppTheme.borderCol)),
                          child: Row(
                            children: [
                              Icon(_isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _isLiked ? Colors.red : AppTheme.textSecondary, size: 18),
                              const SizedBox(width: 6),
                              Text('$_likesCount Beğeni', style: TextStyle(color: _isLiked ? Colors.red : AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.borderCol)),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textSecondary, size: 18),
                            const SizedBox(width: 6),
                            Text('${_comments.length} Yorum', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),

                  // Comments Section Title
                  const Text('YORUMLAR', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 12),

                  // Comments list
                  _isLoadingComments
                      ? const Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Henüz yorum yapılmamış. İlk yorumu sen yap!', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                final commentUser = comment['user'] ?? {};
                                final String cName = commentUser['name'] ?? 'Kullanıcı';
                                final String? cAvatar = commentUser['avatar_url'];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage: cAvatar != null ? CachedNetworkImageProvider(cAvatar) : null,
                                        child: cAvatar == null ? const Icon(Icons.person, size: 16) : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(cName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                            const SizedBox(height: 4),
                                            Text(comment['comment'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                                            const SizedBox(height: 4),
                                            Text(
                                              comment['created_at']?.split('T')?.first ?? '',
                                              style: const TextStyle(color: Colors.white24, fontSize: 9),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ),

          // Comment Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFF0F0D1A), border: Border(top: BorderSide(color: AppTheme.borderCol))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Yorumunuzu yazın...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF0C0A10),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _postComment,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
