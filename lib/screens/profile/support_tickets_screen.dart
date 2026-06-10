import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({Key? key}) : super(key: key);

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _tickets = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _api.getSupportTickets();
      if (mounted) {
        setState(() {
          _tickets = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Destek talepleri yüklenemedi: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _openNewTicketDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF151324),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Yeni Destek Talebi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Konu / Başlık',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF0C0A10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Açıklama / Mesajınız',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF0C0A10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final msg = messageController.text.trim();
                    if (title.isEmpty || msg.isEmpty) return;

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);

                    try {
                      final res = await _api.createSupportTicket(title: title, message: msg);
                      if (res['success'] == true) {
                        _loadTickets();
                      }
                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Talep Oluştur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        title: const Text('Destek Taleplerim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _tickets.isEmpty
                  ? _buildEmptyState()
                  : _buildTicketsList(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6366F1),
        onPressed: _openNewTicketDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎧', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text('Henüz Açık Talebiniz Yok', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Herhangi bir konuda yardım almak için sağ alttaki "+" butonuna tıklayarak yeni bir talep oluşturabilirsiniz.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final status = ticket['status'] ?? 'pending';

        Color badgeColor;
        String statusText;
        if (status == 'closed') {
          badgeColor = Colors.grey;
          statusText = 'Kapatıldı';
        } else if (status == 'answered') {
          badgeColor = Colors.green;
          statusText = 'Cevaplandı';
        } else {
          badgeColor = Colors.amber;
          statusText = 'İnceleniyor';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderCol),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ticket['title'] ?? 'Konu Yok',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ticket['latest_message'] != null)
                    Text(
                      ticket['latest_message']['body'] ?? '',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Son Güncelleme: ${ticket['updated_at']?.split('T')?.first ?? ''}',
                    style: const TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TicketDetailScreen(ticketId: ticket['id'] as int),
                ),
              ).then((_) => _loadTickets());
            },
          ),
        );
      },
    );
  }
}

// ─── Ticket Details Screen ──────────────────────────────────────────────────

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;

  const TicketDetailScreen({Key? key, required this.ticketId}) : super(key: key);

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _ticket = {};
  List<dynamic> _messages = [];
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTicketDetails() async {
    try {
      final res = await _api.getSupportTicketDetails(widget.ticketId);
      if (mounted) {
        setState(() {
          _ticket = res['ticket'] as Map<String, dynamic>? ?? {};
          _messages = res['messages'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 30),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    try {
      final res = await _api.replySupportTicket(ticketId: widget.ticketId, message: text);
      if (res['success'] == true) {
        setState(() {
          _messages.add(res['message']);
          _ticket['status'] = 'pending';
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cevap gönderilemedi: $e')));
      }
    }
  }

  Future<void> _closeTicket() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Talebi Kapat', style: TextStyle(color: Colors.white)),
        content: const Text('Bu destek talebini kapatmak istediğinize emin misiniz? Kapatılan talepler tekrar açılmaz.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kapat', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.closeSupportTicket(widget.ticketId);
      if (res['success'] == true) {
        setState(() {
          _ticket['status'] = 'closed';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destek talebi başarıyla kapatıldı.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isClosed = _ticket['status'] == 'closed';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        title: Text(_ticket['title'] ?? 'Detay', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (!isClosed)
            TextButton(
              onPressed: _closeTicket,
              child: const Text('Kapat', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Warning / Status Banner
                if (isClosed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.black45,
                    child: const Text(
                      '🔒 Bu destek talebi kapatılmıştır. Mesaj gönderilemez.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Messages list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final bool isAdmin = msg['is_admin'] ?? false;

                      return Align(
                        alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isAdmin ? const Color(0xFF1E1B2E) : const Color(0xFF6366F1),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isAdmin ? 0 : 16),
                              bottomRight: Radius.circular(isAdmin ? 16 : 0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['body'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                msg['created_at']?.split('T')?.last?.substring(0, 5) ?? '',
                                style: TextStyle(color: isAdmin ? Colors.white38 : Colors.white60, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Reply Input Bar
                if (!isClosed)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F0D1A),
                      border: Border(top: BorderSide(color: AppTheme.borderCol)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Cevabınızı buraya yazın...',
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
                            onPressed: _sendReply,
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
