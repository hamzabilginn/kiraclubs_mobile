import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({Key? key}) : super(key: key);

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form Fields
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _cryptoAddressController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _ibanController.dispose();
    _accountNameController.dispose();
    _bankNameController.dispose();
    _cryptoAddressController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal(double userBalance, String country) async {
    if (!_formKey.currentState!.validate()) return;

    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr);
    if (amount == null || amount < 350) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum çekim tutarı 350 kredidir.')));
      return;
    }

    if (amount > userBalance) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetersiz bakiye.')));
      return;
    }

    setState(() => _isLoading = true);

    final isTr = country == 'TR';
    final method = isTr ? 'bank' : 'crypto';

    try {
      final res = await _api.requestWithdrawal(
        amount: amount,
        paymentMethod: method,
        iban: isTr ? _ibanController.text.trim() : null,
        accountName: isTr ? _accountNameController.text.trim() : null,
        bankName: isTr ? _bankNameController.text.trim() : null,
        cryptoAddress: !isTr ? _cryptoAddressController.text.trim() : null,
      );

      setState(() => _isLoading = false);

      if (res['success'] == true) {
        if (mounted) {
          // Refresh auth user state (to show updated balance)
          Provider.of<AuthProvider>(context, listen: false).loadUser();
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.cardColor,
              title: const Text('Tebrikler!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Text(res['message'] ?? 'Para çekme talebiniz başarıyla oluşturuldu. Kontrollerin ardından hesabınıza aktarılacaktır.', style: const TextStyle(color: AppTheme.textSecondary)),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Tamam'),
                )
              ],
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Talep oluşturulamadı: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String country = user.country ?? 'TR';
    final bool isTr = country == 'TR';
    final double balance = (user.earnedCoins).toDouble();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        title: const Text('Para Çek', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF064E3B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF065F46).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
                  ]
                ),
                child: Column(
                  children: [
                    const Text('ÇEKİLEBİLİR KAZANÇ', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      '${balance.toStringAsFixed(0)} Kredi',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Karşılığı: \$${(balance / 30).toStringAsFixed(2)} USD',
                      style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payout Form Card
              const Text('ÇEKİM DETAYLARI', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Lütfen tutar girin.';
                        final amt = double.tryParse(value);
                        if (amt == null || amt < 350) return 'Min. çekim tutarı 350 kredidir.';
                        if (amt > balance) return 'Yetersiz bakiye.';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Çekilecek Kredi Tutarı',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'En az 350',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0xFF0C0A10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isTr) ...[
                      // IBAN Field
                      TextFormField(
                        controller: _ibanController,
                        style: const TextStyle(color: Colors.white),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Lütfen IBAN girin.' : null,
                        decoration: InputDecoration(
                          labelText: 'IBAN (TR ile başlayan)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF0C0A10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Account Name Field
                      TextFormField(
                        controller: _accountNameController,
                        style: const TextStyle(color: Colors.white),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Lütfen Alıcı Ad Soyad girin.' : null,
                        decoration: InputDecoration(
                          labelText: 'Alıcı Ad Soyad',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF0C0A10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bank Name Field
                      TextFormField(
                        controller: _bankNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Banka Adı (İsteğe Bağlı)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF0C0A10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ] else ...[
                      // USDT TRC20 Address Field
                      TextFormField(
                        controller: _cryptoAddressController,
                        style: const TextStyle(color: Colors.white),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Lütfen cüzdan adresinizi girin.' : null,
                        decoration: InputDecoration(
                          labelText: 'USDT TRC20 Wallet Address',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: 'T ile başlayan TRON adresi',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF0C0A10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '⚠️ Lütfen cüzdan adresinizin TRC-20 (TRON) ağında olduğundan emin olun. Hatalı gönderimlerin telafisi yoktur.',
                        style: TextStyle(color: Colors.amber, fontSize: 10, height: 1.4),
                      ),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _submitWithdrawal(balance, country),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Para Çekme Talebi Oluştur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Educational Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderCol),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ℹ️ ÇEKİM KURALLARI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 8),
                    Text(
                      '• Çekim işlemleri sadece doğrulanmış Mavi Tikli kadın yayıncılar için geçerlidir.\n'
                      '• Minimum para çekme limiti 350 kredidir.\n'
                      '• Kazanç kuru standart olarak 30 kredi = \$1 USD şeklinde hesaplanır.\n'
                      '• Banka transferi ve kripto ödemeleri güvenlik denetimlerinin ardından 1-3 iş günü içinde tamamlanır.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.6),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
