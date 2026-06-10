import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import 'withdrawal_screen.dart';

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
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: AppTheme.primaryGradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: AppTheme.primaryColor.withOpacity(0.35),
          blurRadius: 24,
          spreadRadius: 2,
        )
      ],
    ),
    child: Column(
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bakiye', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('$tokens Jeton',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          ])),
          Container(width: 1, height: 50, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 20)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kazanç', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('$earned Coin',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          ])),
        ]),
        const SizedBox(height: 16),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showDepositSheet,
                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor, size: 18),
                label: const Text('Bakiye Yükle', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WithdrawalScreen()),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 18),
                label: const Text('Para Çek', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white60),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  void _showDepositSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String method = 'bank'; // or 'crypto'
        final amountCtrl = TextEditingController();
        final nameCtrl = TextEditingController();
        final txidCtrl = TextEditingController();
        bool loading = false;
        final formKey = GlobalKey<FormState>();

        const bankIban = 'TR66 0006 2001 2690 0006 6579 61';
        const bankName = 'Garanti BBVA';
        const bankOwner = 'Mustafa Hazar Bilgin';
        const cryptoAddress = 'TQtbWHFj89guzBTpEsWTxNd5svBMjJvcLY';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: const BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Manuel Bakiye Yükle',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Banka havalesi veya USDT TRC-20 ile bakiye yükleme bildirimi oluşturun. Oran: 1 USD / USDT = 30 Jeton.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      // Tabs
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => method = 'bank'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: method == 'bank' ? AppTheme.primaryColor : const Color(0xFF0C0A10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: method == 'bank' ? AppTheme.primaryColor : AppTheme.borderCol),
                                ),
                                child: const Center(
                                  child: Text('Banka Havalesi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => method = 'crypto'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: method == 'crypto' ? AppTheme.primaryColor : const Color(0xFF0C0A10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: method == 'crypto' ? AppTheme.primaryColor : AppTheme.borderCol),
                                ),
                                child: const Center(
                                  child: Text('Kripto (USDT TRC20)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Payment Instructions Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C0A10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ÖDEME BİLGİLERİ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            if (method == 'bank') ...[
                              _buildInstructionRow('Banka', bankName),
                              _buildInstructionRow('Alıcı', bankOwner),
                              _buildInstructionRowWithCopy('IBAN', bankIban),
                              const SizedBox(height: 8),
                              const Text(
                                '⚠️ Not: Lütfen havale açıklamasına KIRA kullanıcı adınızı yazın. Ödeme güncel USD kuru üzerinden hesaplanır.',
                                style: TextStyle(color: Colors.amber, fontSize: 10, height: 1.4),
                              ),
                            ] else ...[
                              _buildInstructionRow('Ağ (Network)', 'USDT TRC-20 (TRON)'),
                              _buildInstructionRowWithCopy('Cüzdan Adresi', cryptoAddress),
                              const SizedBox(height: 8),
                              const Text(
                                '⚠️ Uyarı: Sadece TRC-20 ağındaki USDT transferleri kabul edilmektedir. Yanlış ağ gönderimleri kurtarılamaz.',
                                style: TextStyle(color: Colors.amber, fontSize: 10, height: 1.4),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Form Fields
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Lütfen tutar girin.';
                          final a = double.tryParse(v);
                          if (a == null || a <= 0) return 'Geçersiz tutar.';
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Yatırılan Tutar (\$ / USDT)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF0C0A10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (method == 'bank')
                        TextFormField(
                          controller: nameCtrl,
                          style: const TextStyle(color: Colors.white),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen ad soyad girin.' : null,
                          decoration: InputDecoration(
                            labelText: 'Gönderen Ad Soyad',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: const Color(0xFF0C0A10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        )
                      else
                        TextFormField(
                          controller: txidCtrl,
                          style: const TextStyle(color: Colors.white),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen TXID girin.' : null,
                          decoration: InputDecoration(
                            labelText: 'İşlem Kodu (TXID)',
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: const Color(0xFF0C0A10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      const SizedBox(height: 24),

                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => loading = true);
                                  try {
                                    final amt = double.parse(amountCtrl.text.trim());
                                    final res = await _api.createDepositRequest(
                                      usdtAmount: amt,
                                      paymentMethod: method,
                                      senderName: method == 'bank' ? nameCtrl.text.trim() : null,
                                      txid: method == 'crypto' ? txidCtrl.text.trim() : null,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                                        content: Text(res['message'] ?? 'Talebiniz başarıyla oluşturuldu.'),
                                        backgroundColor: Colors.green,
                                      ));
                                      _loadWallet();
                                    }
                                  } catch (e) {
                                    setModalState(() => loading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('Hata oluştu: $e'),
                                        backgroundColor: Colors.red,
                                      ));
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Bakiye Bildirimi Gönder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInstructionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInstructionRowWithCopy(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          Row(
            children: [
              SelectableText(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Kopyalandı! 📋'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                child: const Icon(Icons.copy_rounded, color: AppTheme.primaryColor, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
