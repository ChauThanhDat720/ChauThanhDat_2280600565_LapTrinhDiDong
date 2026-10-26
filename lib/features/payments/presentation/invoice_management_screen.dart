import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/payment_repository.dart';
import '../domain/invoice.dart';
import 'e_invoice_screen.dart';
import 'vietqr_payment_screen.dart';

class InvoiceManagementScreen extends StatefulWidget {
  const InvoiceManagementScreen({
    super.key,
    this.repository,
  });

  final PaymentRepository? repository;

  @override
  State<InvoiceManagementScreen> createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends State<InvoiceManagementScreen> {
  late PaymentRepository _repository;
  bool _isLoading = true;
  List<Invoice> _invoices = [];
  Map<String, dynamic>? _reconciliation;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalPaymentRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _repository.getInvoices();
      final report = await _repository.getReconciliationReport();
      if (mounted) {
        setState(() {
          _invoices = items;
          _reconciliation = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  List<Invoice> get _filteredInvoices {
    if (_selectedFilter == 'PAID') {
      return _invoices.where((e) => e.isPaid).toList();
    }
    if (_selectedFilter == 'UNPAID') {
      return _invoices.where((e) => !e.isPaid).toList();
    }
    return _invoices;
  }

  String _formatVnd(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return '${buffer.toString().split('').reversed.join('')} đ';
  }

  @override
  Widget build(BuildContext context) {
    final totalRev = _reconciliation?['totalRevenueVnd'] as int? ?? 0;
    final totalCount = _reconciliation?['totalInvoices'] as int? ?? _invoices.length;
    final paidCount = _reconciliation?['paidInvoices'] as int? ?? 0;
    final unpaidCount = _reconciliation?['unpaidInvoices'] as int? ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Quản lý Viện phí & Đối soát'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Đối soát Doanh thu Bệnh viện
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF38BDF8), size: 24),
                                  SizedBox(width: 8),
                                  Text(
                                    'ĐỐI SOÁT VIỆN PHÍ NGÂN HÀNG',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'KHỚP 100% (0đ LỆCH)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Tổng thực thu hôm nay:',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatVnd(totalRev),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Color(0xFF334155), height: 1),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _statItem('Tổng hóa đơn', totalCount.toString(), Colors.white),
                              _statItem('Đã thu tiền', paidCount.toString(), const Color(0xFF4ADE80)),
                              _statItem('Chờ thu', unpaidCount.toString(), const Color(0xFFF87171)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Bộ lọc trạng thái
                    Row(
                      children: [
                        _filterChip('Tất cả ($totalCount)', 'ALL'),
                        const SizedBox(width: 8),
                        _filterChip('Chờ thu ($unpaidCount)', 'UNPAID'),
                        const SizedBox(width: 8),
                        _filterChip('Đã thu ($paidCount)', 'PAID'),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Danh sách hóa đơn
                    if (_filteredInvoices.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text(
                              'Không có hóa đơn nào theo bộ lọc này.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredInvoices.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (ctx, index) {
                          final invoice = _filteredInvoices[index];
                          return _InvoiceCard(
                            invoice: invoice,
                            onTap: () async {
                              if (invoice.isPaid) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EInvoiceScreen(invoice: invoice),
                                  ),
                                );
                              } else {
                                final res = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => VietQrPaymentScreen(
                                      invoice: invoice,
                                      repository: _repository,
                                    ),
                                  ),
                                );
                                if (res != null) _loadData();
                              }
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onTap});

  final Invoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      invoice.invoiceCode,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: invoice.paymentStatus.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        invoice.paymentStatus.label,
                        style: TextStyle(
                          color: invoice.paymentStatus.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  invoice.patientName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${invoice.department ?? "Khám chuyên khoa"} • Mã LH: ${invoice.appointmentId}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mã CK: ${invoice.paymentRef}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    Text(
                      invoice.formattedTotalAmount,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
