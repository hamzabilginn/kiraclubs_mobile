import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class AgencyScreen extends StatefulWidget {
  const AgencyScreen({Key? key}) : super(key: key);

  @override
  State<AgencyScreen> createState() => _AgencyScreenState();
}

class _AgencyScreenState extends State<AgencyScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorMessage;

  // State data
  bool _isOwner = false;
  bool _inAgency = false;
  Map<String, dynamic> _agencyData = {};
  Map<String, dynamic> _statsData = {};
  List<dynamic> _members = [];
  Map<String, dynamic> _personalData = {};
  List<dynamic> _availableAgencies = [];

  final TextEditingController _inviteCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAgencyData();
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAgencyData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.getAgencyIndex();
      if (mounted) {
        setState(() {
          _isOwner = res['is_owner'] as bool? ?? false;
          _inAgency = res['in_agency'] as bool? ?? false;
          if (_inAgency) {
            _agencyData = res['agency'] as Map<String, dynamic>? ?? {};
            if (_isOwner) {
              _statsData = res['stats'] as Map<String, dynamic>? ?? {};
              _members = res['members'] as List<dynamic>? ?? [];
            } else {
              _personalData = res['personal'] as Map<String, dynamic>? ?? {};
            }
          } else {
            _availableAgencies = res['agencies'] as List<dynamic>? ?? [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Ajans bilgileri yüklenemedi: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinAgency() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await _api.joinAgency(code);
      if (res['success'] == true) {
        _inviteCodeController.clear();
        _loadAgencyData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res['message'] ?? 'Ajansa başarıyla katıldınız!'),
            backgroundColor: Colors.green,
          ));
        }
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

  Future<void> _toggleFreeze(int memberId) async {
    try {
      final res = await _api.toggleAgencyPublisherFreeze(memberId);
      if (res['success'] == true) {
        _loadAgencyData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _removePublisher(int memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Yayıncıyı Çıkar', style: TextStyle(color: Colors.white)),
        content: const Text('Bu yayıncıyı ajansınızdan çıkarmak istediğinize emin misiniz?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çıkar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.removeAgencyPublisher(memberId);
      if (res['success'] == true) {
        _loadAgencyData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _editCommission(int memberId, double currentRate) async {
    final rateController = TextEditingController(text: currentRate.toStringAsFixed(0));
    final newRate = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Komisyon Güncelle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: rateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Yeni Komisyon Oranı (%)',
            labelStyle: TextStyle(color: Colors.white70),
            hintText: 'En fazla 30',
            hintStyle: TextStyle(color: Colors.white30),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              final rate = double.tryParse(rateController.text);
              if (rate != null && rate >= 0 && rate <= 30) {
                Navigator.pop(ctx, rate);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Geçerli bir oran girin (0-30)')));
              }
            }, 
            child: const Text('Güncelle')
          ),
        ],
      ),
    );

    rateController.dispose();
    if (newRate == null) return;

    try {
      final res = await _api.updateAgencyPublisherCommission(memberId, newRate);
      if (res['success'] == true) {
        _loadAgencyData();
      }
    } catch (e) {
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
        title: const Text('Ajans Yönetimi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAgencyData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : !_inAgency
                  ? _buildGuestView()
                  : _isOwner
                      ? _buildOwnerView()
                      : _buildMemberView(),
    );
  }

  // ─── Guest View ────────────────────────────────────────────────────────────

  Widget _buildGuestView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚀 Bir Ajansa Katıl', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'KiraClubs yayıncısı olarak kazanç elde etmeye başlamak için bir ajansa katılarak komisyon oranınızı ve ödemelerinizi garanti altına alabilirsiniz.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Code Input Card
          const Text('KOD İLE KATIL', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderCol),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _inviteCodeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.white54),
                    hintText: 'Davet Kodu',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF0C0A10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _joinAgency,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Davet Kodunu Doğrula', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Public Agencies List
          const Text('AKTİF AJANSLAR', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_availableAgencies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Şu anda aktif ajans bulunamadı.', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _availableAgencies.length,
              itemBuilder: (context, index) {
                final agency = _availableAgencies[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderCol),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: agency['owner_avatar'] != null ? CachedNetworkImageProvider(agency['owner_avatar']) : null,
                        child: agency['owner_avatar'] == null ? const Icon(Icons.business, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(agency['name'] ?? 'Ajans', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Sahibi: ${agency['owner_name']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text('%${agency['commission_rate']} Komisyon', style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () {
                              _inviteCodeController.text = agency['invite_code'] ?? '';
                            },
                            child: const Text('Kodu Seç', style: TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── Owner View ────────────────────────────────────────────────────────────

  Widget _buildOwnerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF1E1B4B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderCol),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_agencyData['name'] ?? 'Ajansım', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(8)),
                      child: Text('Kod: ${_agencyData['invite_code']}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCol('Toplam Yayıncı', _statsData['total_publishers']?.toString() ?? '0'),
                    _buildStatCol('Bugünkü Komisyon', '${_statsData['today_earnings'] ?? 0} C'),
                    _buildStatCol('Toplam Komisyon', '${_statsData['total_earnings'] ?? 0} C'),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Members list
          const Text('AJANS YAYINCILARI', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Ajansınıza kayıtlı yayıncı bulunmuyor.', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                final bool isOnline = member['is_online'] ?? false;
                final bool isFrozen = member['is_agency_frozen'] ?? false;

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
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: member['avatar_url'] != null ? CachedNetworkImageProvider(member['avatar_url']) : null,
                            child: member['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: AppTheme.cardColor, width: 1.5)),
                              ),
                            )
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member['name'] ?? 'Yayıncı', style: TextStyle(color: isFrozen ? Colors.white38 : Colors.white, fontWeight: FontWeight.bold, fontSize: 13, decoration: isFrozen ? TextDecoration.lineThrough : null)),
                            const SizedBox(height: 4),
                            Text('Komisyon: %${member['commission_rate']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                            onPressed: () => _editCommission(member['id'], double.parse(member['commission_rate'].toString())),
                          ),
                          IconButton(
                            icon: Icon(isFrozen ? Icons.play_arrow_outlined : Icons.lock_outline, color: isFrozen ? Colors.green : Colors.amber, size: 20),
                            onPressed: () => _toggleFreeze(member['id']),
                            tooltip: isFrozen ? 'Dondurmayı Kaldır' : 'Dondur',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _removePublisher(member['id']),
                            tooltip: 'Ajanstan Çıkar',
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── Member View ───────────────────────────────────────────────────────────

  Widget _buildMemberView() {
    final personal = _personalData;
    final bool isFrozen = personal['is_agency_frozen'] ?? false;
    final recentGifts = personal['recent_gifts'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFrozen)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), border: Border.all(color: Colors.red.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hesabınız Ajans Tarafından Dondurulmuştur. Lütfen ajans yöneticiniz ile iletişime geçin.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            ),

          // Member Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF022C22)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderCol),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_agencyData['name'] ?? 'Ajans Üyesi', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Ajans Sahibi: ${_agencyData['owner_name']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCol('Komisyon Oranın', '%${personal['commission_rate'] ?? 0}'),
                    _buildStatCol('Bugünkü Kazanç', '${personal['today_earnings'] ?? 0} C'),
                    _buildStatCol('Toplam Kazanç', '${personal['total_earnings'] ?? 0} C'),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recent gifts received
          const Text('SON HEDİYE KAZANÇLARI', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (recentGifts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Henüz hediye kazancınız bulunmuyor.', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentGifts.length,
              itemBuilder: (context, index) {
                final gift = recentGifts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderCol),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: gift['sender_avatar'] != null ? CachedNetworkImageProvider(gift['sender_avatar']) : null,
                        child: gift['sender_avatar'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${gift['sender_name']} tarafından gönderildi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('${gift['gift_emoji']} ${gift['gift_name']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text('+${gift['price']} Kredi', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13))
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
