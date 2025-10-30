import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/sale_order_line_model.dart';
import '../../data/models/order_totals_model.dart';
import '../bloc/sale_order/sale_order_bloc.dart';
import '../bloc/sale_order/sale_order_event.dart';
import '../bloc/sale_order/sale_order_state.dart';

class OrderTotalsWidget extends StatefulWidget {
  final int partnerId;
  final List<SaleOrderLine> orderLines;
  final bool isEditing;
  
  const OrderTotalsWidget({
    super.key,
    required this.partnerId,
    required this.orderLines,
    this.isEditing = false,
  });
  
  @override
  State<OrderTotalsWidget> createState() => _OrderTotalsWidgetState();
}

class _OrderTotalsWidgetState extends State<OrderTotalsWidget> {
  Timer? _calculationTimer;
  String? _lastCalculationKey;
  String _fmtCurrency(num value) {
    int n = value.round();
    final s = n.toString();
    final sb = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      sb.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) sb.write('.');
    }
    final rev = sb.toString().split('').reversed.join();
    return ' 4$rev';
  }
  
  Widget _buildRow(BuildContext context, String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            _fmtCurrency(amount),
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
  
  @override
  void initState() {
    super.initState();
    print('🔄 ORDER_TOTALS_WIDGET: initState called');
    print('🔄 ORDER_TOTALS_WIDGET: partnerId: ${widget.partnerId}');
    print('🔄 ORDER_TOTALS_WIDGET: orderLines.length: ${widget.orderLines.length}');
    _scheduleCalculation();
  }
  
  @override
  void didUpdateWidget(OrderTotalsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    print('🔄 ORDER_TOTALS_WIDGET: didUpdateWidget called');
    print('🔄 ORDER_TOTALS_WIDGET: old partnerId: ${oldWidget.partnerId} -> new: ${widget.partnerId}');
    print('🔄 ORDER_TOTALS_WIDGET: old orderLines.length: ${oldWidget.orderLines.length} -> new: ${widget.orderLines.length}');
    
    // Solo recalcular si cambió el partner o las líneas de orden
    if (oldWidget.partnerId != widget.partnerId || 
        oldWidget.orderLines.length != widget.orderLines.length ||
        _orderLinesChanged(oldWidget.orderLines, widget.orderLines)) {
      print('🔄 ORDER_TOTALS_WIDGET: Changes detected, scheduling calculation');
      _scheduleCalculation();
    } else {
      print('⏭️ ORDER_TOTALS_WIDGET: No changes detected, skipping calculation');
    }
  }
  
  @override
  void dispose() {
    _calculationTimer?.cancel();
    super.dispose();
  }
  
  /// Verifica si las líneas de orden cambiaron
  bool _orderLinesChanged(List<SaleOrderLine> oldLines, List<SaleOrderLine> newLines) {
    print('🔍 ORDER_TOTALS_WIDGET: _orderLinesChanged called');
    print('🔍 ORDER_TOTALS_WIDGET: oldLines.length: ${oldLines.length}');
    print('🔍 ORDER_TOTALS_WIDGET: newLines.length: ${newLines.length}');
    
    if (oldLines.length != newLines.length) {
      print('🔍 ORDER_TOTALS_WIDGET: Length changed, returning true');
      return true;
    }
    
    for (int i = 0; i < oldLines.length; i++) {
      print('🔍 ORDER_TOTALS_WIDGET: Comparing line $i:');
      print('🔍 ORDER_TOTALS_WIDGET:   old productId: ${oldLines[i].productId} -> new: ${newLines[i].productId}');
      print('🔍 ORDER_TOTALS_WIDGET:   old quantity: ${oldLines[i].quantity} -> new: ${newLines[i].quantity}');
      print('🔍 ORDER_TOTALS_WIDGET:   old priceUnit: ${oldLines[i].priceUnit} -> new: ${newLines[i].priceUnit}');
      
      if (oldLines[i].productId != newLines[i].productId ||
          oldLines[i].quantity != newLines[i].quantity ||
          oldLines[i].priceUnit != newLines[i].priceUnit) {
        print('🔍 ORDER_TOTALS_WIDGET: Line $i changed, returning true');
        return true;
      }
    }
    
    print('🔍 ORDER_TOTALS_WIDGET: No changes detected, returning false');
    return false;
  }
  
  /// Programa el cálculo con debouncing
  void _scheduleCalculation() {
    print('🔄 ORDER_TOTALS_WIDGET: _scheduleCalculation called');
    print('🔄 ORDER_TOTALS_WIDGET: partnerId: ${widget.partnerId}');
    print('🔄 ORDER_TOTALS_WIDGET: orderLines.length: ${widget.orderLines.length}');
    print('🔄 ORDER_TOTALS_WIDGET: isEditing: ${widget.isEditing}');
    
    // NO calcular totales si estamos en modo de edición
    if (widget.isEditing) {
      print('🔄 ORDER_TOTALS_WIDGET: ⚠️ EDITING MODE - Skipping calculation to avoid temp orders');
      return;
    }
    
    _calculationTimer?.cancel();
    _calculationTimer = Timer(const Duration(milliseconds: 500), () {
      print('⏰ ORDER_TOTALS_WIDGET: Timer fired');
      print('⏰ ORDER_TOTALS_WIDGET: mounted: $mounted');
      print('⏰ ORDER_TOTALS_WIDGET: partnerId > 0: ${widget.partnerId > 0}');
      print('⏰ ORDER_TOTALS_WIDGET: orderLines.isNotEmpty: ${widget.orderLines.isNotEmpty}');
      
      if (mounted && widget.partnerId > 0 && widget.orderLines.isNotEmpty) {
        final currentKey = _generateCalculationKey();
        print('🔑 ORDER_TOTALS_WIDGET: currentKey: $currentKey');
        print('🔑 ORDER_TOTALS_WIDGET: lastCalculationKey: $_lastCalculationKey');
        
        if (_lastCalculationKey != currentKey) {
          _lastCalculationKey = currentKey;
          print('🚀 ORDER_TOTALS_WIDGET: Dispatching CalculateOrderTotals event');
          context.read<SaleOrderBloc>().add(CalculateOrderTotals(
            partnerId: widget.partnerId,
            orderLines: widget.orderLines,
          ));
        } else {
          print('⏭️ ORDER_TOTALS_WIDGET: Skipping calculation (same key)');
        }
      } else {
        print('❌ ORDER_TOTALS_WIDGET: Conditions not met for calculation');
      }
    });
  }
  
  /// Genera una clave única para el cálculo actual
  String _generateCalculationKey() {
    final linesKey = widget.orderLines
        .map((line) => '${line.productId}:${line.quantity}:${line.priceUnit}')
        .join(',');
    return '${widget.partnerId}_$linesKey';
  }
  
  @override
  Widget build(BuildContext context) {
    // Mientras se edita, mostramos un cálculo local inmediato para evitar el loop de loading
    if (widget.isEditing) {
      final localTotals = _calculateLocalTotals(widget.orderLines);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen (edición)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _buildRow(context, 'Subtotal:', localTotals.amountUntaxed),
              // Mostrar impuestos estimados como 0 durante edición
              _buildRow(context, 'Impuestos (estimado):', 0.0),
              const Divider(),
              _buildRow(context, 'Total:', localTotals.amountTotal, isTotal: true),
              const SizedBox(height: 6),
              Text(
                'Los impuestos definitivos se calculan al guardar.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return BlocBuilder<SaleOrderBloc, SaleOrderState>(
      builder: (context, state) {
        // Verificar si hay datos suficientes para calcular
        if (widget.partnerId == 0 || widget.orderLines.isEmpty) {
          return const _NoDataTotals();
        }
        
        if (state is SaleOrderCalculatingTotals) {
          return const _LoadingTotals();
        } else if (state is SaleOrderTotalsCalculated) {
          return _TotalsContent(totals: state.totals);
        } else if (state is SaleOrderError) {
          return _ErrorTotals(message: state.message);
        }
        
        // Estado inicial - mostrar loading
        return const _LoadingTotals();
      },
    );
  }

  // Cálculo local de totales para modo edición (sin llamadas a servidor)
  OrderTotals _calculateLocalTotals(List<SaleOrderLine> lines) {
    double amountUntaxed = 0.0;
    for (final line in lines) {
      final subtotal = line.priceSubtotal.toDouble();
      if (subtotal > 0) {
        amountUntaxed += subtotal;
      } else {
        final qty = (line.quantity).toDouble();
        final unit = (line.priceUnit).toDouble();
        amountUntaxed += qty * unit;
      }
    }
    return OrderTotals(
      amountUntaxed: amountUntaxed,
      amountTax: 0.0,
      amountTotal: amountUntaxed,
      taxGroups: const [],
    );
  }
}

class _LoadingTotals extends StatelessWidget {
  const _LoadingTotals();
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 8),
            Text(
              'Calculando totales...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsContent extends StatelessWidget {
  final OrderTotals totals;
  
  const _TotalsContent({required this.totals});
  String _fmtCurrency(num value) {
    int n = value.round();
    final s = n.toString();
    final sb = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      sb.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) sb.write('.');
    }
    final rev = sb.toString().split('').reversed.join();
    return '\u00024$rev';
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildTotalRow(context, 'Subtotal:', totals.amountUntaxed),
            ...totals.taxGroups.map((group) => 
              _buildTotalRow(context, '${group.name}:', group.amount)
            ),
            if (totals.taxGroups.isEmpty && totals.amountTax > 0)
              _buildTotalRow(context, 'Impuestos:', totals.amountTax),
            const Divider(),
            _buildTotalRow(context, 'Total:', totals.amountTotal, isTotal: true),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTotalRow(BuildContext context, String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal 
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            _fmtCurrency(amount),
            style: isTotal 
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorTotals extends StatelessWidget {
  final String message;
  
  const _ErrorTotals({required this.message});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error calculando totales: $message',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Usando cálculo local...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDataTotals extends StatelessWidget {
  const _NoDataTotals();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Selecciona un cliente y agrega productos para ver el resumen',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
