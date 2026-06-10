import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'package:intl/intl.dart';

class WalletHistoryScreen extends StatelessWidget {
  final List<dynamic> transactions;

  const WalletHistoryScreen({Key? key, required this.transactions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0D1A),
        elevation: 0,
        title: const Text('Cüzdan Geçmişi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text('Henüz işlem bulunmuyor.', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final type = tx['type'] as String? ?? 'deposit';
                final isPositive = type == 'deposit' || type == 'gift_received';
                final amount = double.tryParse(tx['amount'].toString()) ?? 0.0;
                final desc = tx['description'] as String? ?? 'İşlem';
                final createdAt = tx['created_at'] as String?;
                
                DateTime? date;
                if (createdAt != null) {
                  try {
                    date = DateTime.parse(createdAt);
                  } catch (_) {}
                }

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
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isPositive ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPositive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isPositive ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              desc,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (date != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMM yyyy, HH:mm').format(date),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
                            ]
                          ],
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${amount.toInt()}',
                        style: TextStyle(
                          color: isPositive ? Colors.green : Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
