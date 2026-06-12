import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
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

  // Controllers
  final TextEditingController _withdrawAmountController = TextEditingController();
  final TextEditingController _withdrawIbanController = TextEditingController();
  final TextEditingController _withdrawAccountNameController = TextEditingController();
  final TextEditingController _withdrawBankNameController = TextEditingController();
  final TextEditingController _withdrawCryptoAddressController = TextEditingController();

  bool _isSubmittingWithdraw = false;

  // In-App Purchase Fields
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _iapAvailable = true;
  bool _productsLoading = true;
  bool _purchasePending = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _initInAppPurchase();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _withdrawAmountController.dispose();
    _withdrawIbanController.dispose();
    _withdrawAccountNameController.dispose();
    _withdrawBankNameController.dispose();
    _withdrawCryptoAddressController.dispose();
    super.dispose();
  }

  void _initInAppPurchase() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      _showToast("Ödeme servisi hatası: $error");
    });
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final bool available = await _iap.isAvailable();
      if (!available) {
        setState(() {
          _iapAvailable = false;
          _productsLoading = false;
        });
        return;
      }

      final ProductDetailsResponse response = await _iap.queryProductDetails(
        AppConstants.tokenProducts.toSet(),
      );

      if (response.notFoundIDs.isNotEmpty) {
        print("Not found product IDs: ${response.notFoundIDs}");
      }

      setState(() {
        _products = response.productDetails;
        // Sort products by coin/token count
        _products.sort((a, b) {
          final aVal = AppConstants.tokenAmounts[a.id] ?? 0;
          final bVal = AppConstants.tokenAmounts[b.id] ?? 0;
          return aVal.compareTo(bVal);
        });
        _productsLoading = false;
      });
    } catch (e) {
      print("Error loading products: $e");
      setState(() {
        _productsLoading = false;
      });
    }
  }

  void _buyProduct(ProductDetails productDetails) {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    setState(() => _purchasePending = true);
    _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() => _purchasePending = true);
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          setState(() => _purchasePending = false);
          _showToast("Satın alım iptal edildi veya bir hata oluştu.");
          print("Purchase error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          final success = await _verifyPurchaseOnBackend(purchaseDetails);
          setState(() => _purchasePending = false);
          if (success) {
            _showToast("Tebrikler! Jetonlar hesabınıza yüklendi. 🎉");
            _loadWallet();
          } else {
            _showToast("Ödeme doğrulanırken bir hata oluştu.");
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _verifyPurchaseOnBackend(PurchaseDetails purchaseDetails) async {
    try {
      final token = purchaseDetails.verificationData.serverVerificationData;
      final res = await _api.verifyGooglePlayPurchase(
        productId: purchaseDetails.productID,
        purchaseToken: token,
      );
      return res['success'] == true;
    } catch (e) {
      print("Verification failed on backend: $e");
      return false;
    }
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
    if (_productsLoading) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    if (!_iapAvailable || _products.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: const Column(
          children: [
            Text('⚠️', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              'Ödeme Servisi Hazırlanıyor',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Uygulama içi ödeme servisi şu anda yüklenemedi. Lütfen internet bağlantınızı kontrol edin veya Google Play Store\'un açık olduğundan emin olun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🪙 JETON YÜKLE',
                style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
              ),
              const SizedBox(height: 4),
              const Text(
                'Satın aldığınız jetonlar hesabınıza anında tanımlanır. Güvenli ödemeler Google Play aracılığıyla gerçekleştirilir.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Product Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: _products.length,
                itemBuilder: (ctx, index) {
                  final product = _products[index];
                  final tokens = AppConstants.tokenAmounts[product.id] ?? 0;
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Coin Icon & Badge
                        Column(
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 32)),
                            const SizedBox(height: 8),
                            Text(
                              '$tokens Kredi',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        
                        // Buy Button
                        GestureDetector(
                          onTap: () => _buyProduct(product),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                product.price,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildDepositHistory(),
            ],
          ),
        ),
        if (_purchasePending)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6366F1)),
                    SizedBox(height: 16),
                    Text(
                      'Satın alım işlemi gerçekleştiriliyor...\nLütfen pencereyi kapatmayın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
