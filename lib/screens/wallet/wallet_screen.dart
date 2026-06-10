import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../profile/edit_profile_screen.dart';
import 'wallet_history_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ApiService _api = ApiService();
  final _depositFormKey = GlobalKey<FormState>();
  final _withdrawFormKey = GlobalKey<FormState>();

  Map<String, dynamic> _wallet = {
    'tokens': 0,
    'earned_coins': 0,
    'transactions': [],
    'deposits': [],
    'withdrawals': []
  };
  bool _isLoading = true;
  String _activeTab = 'deposit'; // 'deposit' or 'withdraw'
  String _depositMethod = 'bank'; // 'bank' or 'crypto'

  // Controllers
  final TextEditingController _depositAmountController = TextEditingController();
  final TextEditingController _depositSenderNameController = TextEditingController();
  final TextEditingController _depositTxidController = TextEditingController();

  final TextEditingController _withdrawAmountController = TextEditingController();
  final TextEditingController _withdrawIbanController = TextEditingController();
  final TextEditingController _withdrawAccountNameController = TextEditingController();
  final TextEditingController _withdrawBankNameController = TextEditingController();
  final TextEditingController _withdrawCryptoAddressController = TextEditingController();

  bool _isSubmittingDeposit = false;
  bool _isSubmittingWithdraw = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    _depositAmountController.dispose();
    _depositSenderNameController.dispose();
    _depositTxidController.dispose();
    _withdrawAmountController.dispose();
    _withdrawIbanController.dispose();
    _withdrawAccountNameController.dispose();
    _withdrawBankNameController.dispose();
    _withdrawCryptoAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    try {
      final w = await _api.getWallet();
      setState(() {
        _wallet = w;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchPolicyUrl() async {
    final url = Uri.parse('https://kiraclubs.com/legal/agency-policy');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showToast('Poliçe sayfası açılamadı.');
      }
    } catch (e) {
      _showToast('Hata: $e');
    }
  }

  Future<void> _submitDeposit() async {
    if (!_depositFormKey.currentState!.validate()) return;

    setState(() => _isSubmittingDeposit = true);
    try {
      final amt = double.parse(_depositAmountController.text.trim());
      final res = await _api.createDepositRequest(
        usdtAmount: amt,
        paymentMethod: _depositMethod,
        senderName: _depositMethod == 'bank' ? _depositSenderNameController.text.trim() : null,
        txid: _depositMethod == 'crypto' ? _depositTxidController.text.trim() : null,
      );

      _depositAmountController.clear();
      _depositSenderNameController.clear();
      _depositTxidController.clear();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Başarılı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(res['message'] ?? 'Yatırım bildiriminiz başarıyla iletildi.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadWallet();
                },
                child: const Text('Tamam'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      _showToast('Hata: $e');
    } finally {
      setState(() => _isSubmittingDeposit = false);
    }
  }

  Future<void> _submitWithdrawal(double userBalance, String country) async {
    if (!_withdrawFormKey.currentState!.validate()) return;

    final amountStr = _withdrawAmountController.text.trim();
    final amount = double.tryParse(amountStr);
    if (amount == null || amount < 350) {
      _showToast('Minimum çekim tutarı 350 kredidir.');
      return;
    }

    if (amount > userBalance) {
      _showToast('Yetersiz bakiye.');
      return;
    }

    setState(() => _isSubmittingWithdraw = true);

    final isTr = country == 'TR';
    final method = isTr ? 'bank' : 'crypto';

    try {
      final res = await _api.requestWithdrawal(
        amount: amount,
        paymentMethod: method,
        iban: isTr ? _withdrawIbanController.text.trim() : null,
        accountName: isTr ? _withdrawAccountNameController.text.trim() : null,
        bankName: isTr ? _withdrawBankNameController.text.trim() : null,
        cryptoAddress: !isTr ? _withdrawCryptoAddressController.text.trim() : null,
      );

      _withdrawAmountController.clear();
      _withdrawIbanController.clear();
      _withdrawAccountNameController.clear();
      _withdrawBankNameController.clear();
      _withdrawCryptoAddressController.clear();

      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).loadUser();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Tebrikler!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(res['message'] ?? 'Para çekme talebiniz başarıyla oluşturuldu. Kontrollerin ardından hesabınıza aktarılacaktır.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadWallet();
                },
                child: const Text('Tamam'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      _showToast('Hata: $e');
    } finally {
      setState(() => _isSubmittingWithdraw = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final isFemale = user?.gender == 'female';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0D1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(user),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          if (isFemale) ...[
                            const SizedBox(height: 8),
                            _buildPolicyLink(),
                            _buildTabSelector(),
                          ],
                          if (_activeTab == 'deposit' || !isFemale)
                            _buildDepositPanel(user)
                          else
                            _buildWithdrawPanel(user),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    "Keşfet'e Dön",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Right section: Title + history button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cüzdanım',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WalletHistoryScreen(
                        transactions: _wallet['transactions'] as List<dynamic>? ?? [],
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_rounded, color: Colors.white70, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyLink() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: GestureDetector(
          onTap: _launchPolicyUrl,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📋 ', style: TextStyle(fontSize: 12)),
              Text(
                'app.agency_policy_rules',
                style: TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 'deposit'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _activeTab == 'deposit' ? const Color(0xFF6366F1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🪙', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 6),
                    Text(
                      'Kredi Yükle',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 'withdraw'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _activeTab == 'withdraw' ? const Color(0xFF6366F1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('💸', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 6),
                    Text(
                      'Para Çek',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositPanel(dynamic user) {
    final country = user?.country ?? 'TR';
    final isTr = country == 'TR';

    const bankIban = 'TR66 0006 2001 2690 0006 6579 61';
    const bankName = 'Garanti BBVA';
    const bankOwner = 'Mustafa Hazar Bilgin';
    const cryptoAddress = 'TQtbWHFj89guzBTpEsWTxNd5svBMjJvcLY';

    return Container(
      margin: const EdgeInsets.all(16),
      child: Form(
        key: _depositFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isTr) ...[
              _buildDepositMethodSelector(),
              const SizedBox(height: 16),
            ],

            // Payment Instructions Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_depositMethod == 'bank' || isTr) ...[
                    const Text('🏦 Banka Havalesi / IBAN Bilgileri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 16),
                    _buildInstructionRow('BANKA ADI', bankName),
                    _buildInstructionRow('HESAP SAHİBİ (ALICI)', bankOwner),
                    _buildInstructionRowWithCopy('IBAN NUMARASI', bankIban),
                  ] else ...[
                    const Text('🪙 USDT TRC20 Yatırma Adresi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 16),
                    _buildInstructionRow('AĞ (NETWORK)', 'USDT TRC-20 (TRON)'),
                    _buildInstructionRowWithCopy('CÜZDAN ADRESİ', cryptoAddress),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Exchange Rate Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.03)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('Kur Oranı', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        SizedBox(height: 4),
                        Text('1 USD = 30 Kredi', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  VerticalDivider(color: Colors.white10),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Min. Yatırım', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        SizedBox(height: 4),
                        Text('1 USD (30 Kredi)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Packages
            const Text(
              '⚡ HIZLI PAKETLER',
              style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildQuickPackageCard('150 Kredi', '5 USD', 5),
                const SizedBox(width: 8),
                _buildQuickPackageCard('300 Kredi', '10 USD', 10),
                const SizedBox(width: 8),
                _buildQuickPackageCard('1500 Kredi', '50 USD', 50),
              ],
            ),
            const SizedBox(height: 20),

            // Input Fields
            const Text('YATIRIM BİLDİRİMİ', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _depositAmountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Lütfen tutar girin.';
                final a = double.tryParse(v);
                if (a == null || a <= 0) return 'Geçersiz tutar.';
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Yatırılan Tutar (USD)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1E293B).withOpacity(0.4),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
              ),
            ),
            const SizedBox(height: 12),

            if (_depositMethod == 'bank' || isTr)
              TextFormField(
                controller: _depositSenderNameController,
                style: const TextStyle(color: Colors.white),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen ad soyad girin.' : null,
                decoration: InputDecoration(
                  labelText: 'Gönderen Ad Soyad',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E293B).withOpacity(0.4),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                ),
              )
            else
              TextFormField(
                controller: _depositTxidController,
                style: const TextStyle(color: Colors.white),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen TXID girin.' : null,
                decoration: InputDecoration(
                  labelText: 'İşlem Kodu (TXID)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E293B).withOpacity(0.4),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                ),
              ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingDeposit ? null : _submitDeposit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmittingDeposit
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('🚀 Kredi Yükleme Talebi Oluştur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
            _buildInstructionsList(_depositMethod == 'bank' || isTr),
            const SizedBox(height: 24),

            // Deposit history list
            _buildDepositHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositMethodSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _depositMethod = 'bank'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _depositMethod == 'bank' ? const Color(0xFF0F0D1A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _depositMethod == 'bank' ? const Color(0xFF6366F1).withOpacity(0.4) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '🏦 Banka Havalesi',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _depositMethod = 'crypto'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _depositMethod == 'crypto' ? const Color(0xFF0F0D1A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _depositMethod == 'crypto' ? const Color(0xFF6366F1).withOpacity(0.4) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '🪙 Kripto (USDT TRC20)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPackageCard(String title, String subtitle, double amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _depositAmountController.text = amount.toStringAsFixed(0);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsList(bool isBank) {
    final title = isBank ? 'Banka Havalesi ile Yatırım Adımları' : 'Kripto ile Nasıl Yatırım Yapılır?';
    final steps = isBank
        ? [
            'Yukarıda belirtilen IBAN numarasına yatırmak istediğiniz tutarın karşılığı olan Türk Lirası veya Dolar tutarını gönderin.',
            'Gönderim yaparken açıklama kısmına KiraClubs kullanıcı adınızı yazın.',
            'Transferi tamamladıktan sonra, yukarıdaki forma yatırdığınız dolar miktarını ve gönderici ad soyad bilgisini girin.',
            '"Kredi Yükleme Talebi Oluştur" butonuna tıklayarak talebinizi iletin.',
            'Müşteri temsilcilerimiz işlemi onayladığında krediniz anında hesabınıza yüklenecektir.'
          ]
        : [
            'Binance, Paribu, BtcTurk gibi bir borsaya girin veya kayıt olun.',
            'Cüzdanınızdan Tether (USDT) alımı yapın.',
            'Çekme (Withdraw) bölümüne gelip para birimi olarak USDT seçin.',
            'Ağ (Network) olarak KESİNLİKLE TRON (TRC20) ağını seçin.',
            'Yukarıda yazan Yatırma Adresini kopyalayıp borsadaki alıcı adresi kısmına yapıştırın.',
            'Tutar girip gönderin. Gönderim tamamlanınca yukarıdaki forma miktarı yazıp bize bildirin! (Otomatik olarak krediniz yüklenecektir).'
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ℹ️ $title', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key + 1}. ', style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12)),
                    Expanded(child: Text(entry.value, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWithdrawPanel(dynamic user) {
    final country = user?.country ?? 'TR';
    final isTr = country == 'TR';
    final double balance = (user?.earnedCoins ?? 0).toDouble();

    if (user?.verificationStatus != 'approved') {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            const Text('🔒', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Hesap Onayı Gerekli',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para çekme talebi oluşturabilmek için profilinizin onaylı (Mavi Tikli) olması gerekmektedir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                '👉 Profilimi Onayla',
                style: TextStyle(color: Color(0xFF0F0D1A), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final hasEnoughBalance = balance >= 350;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Form(
        key: _withdrawFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Earned coins info card
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
                  BoxShadow(color: const Color(0xFF065F46).withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                children: [
                  const Text('ÇEKİLEBİLİR KAZANÇ', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  Text(
                    '${balance.toStringAsFixed(0)} Kredi',
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Karşılığı: \$${(balance / 30).toStringAsFixed(2)} USD',
                    style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Kazancı Çek (USDT TRC20)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Form inputs
            TextFormField(
              controller: _withdrawAmountController,
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
                labelText: 'Çekilecek Tutar (Kredi)',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Örn: 500',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E293B).withOpacity(0.4),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
              ),
            ),
            const SizedBox(height: 12),

            if (isTr) ...[
              TextFormField(
                controller: _withdrawIbanController,
                style: const TextStyle(color: Colors.white),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Lütfen IBAN girin.' : null,
                decoration: InputDecoration(
                  labelText: 'IBAN Numarası',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'TR00 0000 0000 0000 0000 0000 00',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B).withOpacity(0.4),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _withdrawAccountNameController,
                style: const TextStyle(color: Colors.white),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Ad Soyad (Hesap Sahibi) girin.' : null,
                decoration: InputDecoration(
                  labelText: 'Ad Soyad (Hesap Sahibi)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Ad Soyad',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B).withOpacity(0.4),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _withdrawBankNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Banka Adı (Opsiyonel)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'Örn: Ziraat Bankası',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B).withOpacity(0.4),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                ),
              ),
            ] else ...[
              TextFormField(
                controller: _withdrawCryptoAddressController,
                style: const TextStyle(color: Colors.white),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Lütfen cüzdan adresinizi girin.' : null,
                decoration: InputDecoration(
                  labelText: 'USDT TRC20 Wallet Address',
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: 'T ile başlayan TRON adresi',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B).withOpacity(0.4),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981))),
                ),
              ),
            ],
            const SizedBox(height: 20),

            if (!hasEnoughBalance) ...[
              const Center(
                child: Text(
                  'Bakiye yetersiz. En az 350 krediniz olmalıdır.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (hasEnoughBalance && !_isSubmittingWithdraw) ? () => _submitWithdrawal(balance, country) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  disabledBackgroundColor: const Color(0xFF1E293B).withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmittingWithdraw
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        '💸 Para Çekme Talebi Oluştur',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Withdrawal instructions card
            _buildWithdrawalInstructions(isTr),
            const SizedBox(height: 24),

            // Withdraw requests history list
            _buildWithdrawalHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalInstructions(bool isTr) {
    final title = isTr ? 'Banka Havalesi ile Çekim Kuralları' : 'Kripto ile Nasıl Çekim Yapılır?';
    final steps = isTr
        ? [
            'Çekim işlemleri sadece doğrulanmış Mavi Tikli kadın yayıncılar için geçerlidir.',
            'Minimum para çekme limiti 350 kredidir.',
            'Kazanç kuru standart olarak 30 kredi = \$1 USD şeklinde hesaplanır.',
            'Banka transferi güvenlik denetimlerinin ardından 1-3 iş günü içinde tamamlanır.'
          ]
        : [
            'Borsanızın Yatırma (Deposit) bölümüne girin.',
            'Kripto para olarak Tether (USDT) seçin.',
            'Ağ (Network) olarak KESİNLİKLE TRON (TRC20) ağını seçtiğinizden emin olun.',
            'Borsanın size verdiği Yatırma Adresini kopyalayın.',
            'O adresi buradaki USDT TRC20 Wallet Address kutusuna yapıştırıp talebinizi oluşturun.',
            'Paranız 24 saat içerisinde kripto borsanızdaki hesabınıza geçecektir!'
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ℹ️ $title', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key + 1}. ', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                    Expanded(child: Text(entry.value, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
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
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
          Row(
            children: [
              SelectableText(value, style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  _showToast('Kopyalandı! 📋');
                },
                child: const Icon(Icons.copy_rounded, color: Color(0xFF6366F1), size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepositHistory() {
    final deposits = _wallet['deposits'] as List<dynamic>? ?? [];
    if (deposits.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📋 Yatırım Geçmişim',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: deposits.length,
          itemBuilder: (ctx, i) {
            final dep = deposits[i];
            final credits = dep['credits'] ?? 0;
            final dateStr = dep['created_at'] != null ? dep['created_at'].toString() : '';
            final status = dep['status'] ?? 'pending';
            final method = dep['payment_method'] ?? 'bank';
            final usdtAmount = dep['usdt_amount'] ?? 0;

            Color statusColor = Colors.amber;
            String statusText = 'Doğrulanıyor';
            if (status == 'approved') {
              statusColor = Colors.green;
              statusText = 'Yüklendi';
            } else if (status == 'rejected') {
              statusColor = Colors.red;
              statusText = 'Reddedildi';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '+$credits Kredi',
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: method == 'crypto' ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              method == 'crypto' ? 'USDT TRC20' : 'BANKA (IBAN)',
                              style: TextStyle(
                                color: method == 'crypto' ? Colors.orange : Colors.blue,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Tarih: $dateStr', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      Text('Tutar: $usdtAmount USD', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWithdrawalHistory() {
    final withdrawals = _wallet['withdrawals'] as List<dynamic>? ?? [];
    if (withdrawals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📋 Çekim Taleplerim',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: withdrawals.length,
          itemBuilder: (ctx, i) {
            final w = withdrawals[i];
            final amount = w['amount'] ?? 0;
            final dateStr = w['created_at'] != null ? w['created_at'].toString() : '';
            final status = w['status'] ?? 'pending';
            final method = w['payment_method'] ?? 'bank';

            Color statusColor = Colors.amber;
            String statusText = 'Beklemede';
            if (status == 'completed') {
              statusColor = Colors.green;
              statusText = 'Gönderildi';
            } else if (status == 'rejected') {
              statusColor = Colors.red;
              statusText = 'Reddedildi';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$amount Kredi',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: method == 'crypto' ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              method == 'crypto' ? 'USDT TRC20' : 'BANKA',
                              style: TextStyle(
                                color: method == 'crypto' ? Colors.orange : Colors.blue,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Tarih: $dateStr', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
