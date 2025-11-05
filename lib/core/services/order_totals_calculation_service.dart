import '../../data/models/sale_order_line_model.dart';
import '../../data/models/order_totals_model.dart';
import 'tax_calculation_service.dart';

/// Clase auxiliar para acumular impuestos por grupo
class TaxGroupAccumulator {
  final String name;
  double totalBase = 0.0;
  double totalAmount = 0.0;
  double? percentage; // Porcentaje del impuesto (null si es fijo)

  TaxGroupAccumulator({required this.name, this.percentage});

  void add(double base, double amount, {double? percentage}) {
    totalBase += base;
    totalAmount += amount;
    // Si aún no tenemos porcentaje y se proporciona uno, guardarlo
    if (this.percentage == null && percentage != null) {
      this.percentage = percentage;
    }
  }

  @override
  String toString() =>
      'TaxGroupAccumulator(name: $name, base: $totalBase, amount: $totalAmount, percentage: $percentage)';
}

/// Servicio para calcular totales completos de una orden
class OrderTotalsCalculationService {
  final TaxCalculationService _taxCalculationService;

  OrderTotalsCalculationService(this._taxCalculationService);

  /// Calcula totales completos de una orden
  ///
  /// [orderLines] Líneas de la orden (con precios ya calculados desde tarifa)
  /// [companyId] ID de la empresa/company para filtrar impuestos
  ///
  /// Retorna [OrderTotals] con los totales calculados
  OrderTotals calculateTotals({
    required List<SaleOrderLine> orderLines,
    required int companyId,
  }) {
    print('💰 ORDER_TOTALS_CALC_SERVICE: Calculando totales de orden');
    print('💰 ORDER_TOTALS_CALC_SERVICE: Líneas: ${orderLines.length}');
    print('💰 ORDER_TOTALS_CALC_SERVICE: Company ID: $companyId');

    // Manejar caso de orden vacía
    if (orderLines.isEmpty) {
      print('ℹ️ ORDER_TOTALS_CALC_SERVICE: Orden vacía - retornando totales en cero');
      return OrderTotals(
        amountUntaxed: 0.0,
        amountTax: 0.0,
        amountTotal: 0.0,
        taxGroups: [],
      );
    }

    // Paso 1: Calcular subtotales por línea y acumular impuestos
    double amountUntaxed = 0.0;
    double totalTaxAmount = 0.0;
    Map<String, TaxGroupAccumulator> taxGroups = {};

    for (final line in orderLines) {
      // Subtotal de la línea (ya calculado desde tarifa)
      final lineSubtotal = line.quantity * line.priceUnit;
      amountUntaxed += lineSubtotal;

      print('💰 ORDER_TOTALS_CALC_SERVICE: Línea ${line.productName}');
      print('   - Cantidad: ${line.quantity}');
      print('   - Precio unitario: ${line.priceUnit}');
      print('   - Subtotal: $lineSubtotal');

      // Calcular impuestos de la línea
      if (line.taxesIds.isNotEmpty) {
        final taxCalc = _taxCalculationService.calculateTaxesForLine(
          baseAmount: lineSubtotal,
          taxIds: line.taxesIds,
          companyId: companyId,
        );

        totalTaxAmount += taxCalc.taxAmount;

        print('💰 ORDER_TOTALS_CALC_SERVICE: Impuestos de línea: ${taxCalc.taxAmount}');
        print('💰 ORDER_TOTALS_CALC_SERVICE: Detalles: ${taxCalc.taxDetails.length} impuestos');

        // Agrupar impuestos por nombre (ya que no usamos tax_group_id)
        for (final detail in taxCalc.taxDetails) {
          final groupName = detail.taxName;
          if (!taxGroups.containsKey(groupName)) {
            taxGroups[groupName] = TaxGroupAccumulator(name: groupName);
            print('💰 ORDER_TOTALS_CALC_SERVICE: Nuevo grupo de impuestos: $groupName');
          }
          taxGroups[groupName]!.add(detail.base, detail.amount, percentage: detail.percentage);
          print('💰 ORDER_TOTALS_CALC_SERVICE: Agregado a grupo $groupName: base=${detail.base}, amount=${detail.amount}, percentage=${detail.percentage}');
        }
      } else {
        print('ℹ️ ORDER_TOTALS_CALC_SERVICE: Línea sin impuestos');
      }
    }

    // Paso 2: Crear TaxGroup list
    final taxGroupsList = taxGroups.values.map((acc) => TaxGroup(
      name: acc.name,
      amount: acc.totalAmount,
      base: acc.totalBase,
      percentage: acc.percentage,
    )).toList();

    // Paso 3: Calcular total
    final amountTotal = amountUntaxed + totalTaxAmount;

    print('✅ ORDER_TOTALS_CALC_SERVICE: Cálculo completado');
    print('💰 ORDER_TOTALS_CALC_SERVICE: Subtotal sin impuestos: $amountUntaxed');
    print('💰 ORDER_TOTALS_CALC_SERVICE: Total de impuestos: $totalTaxAmount');
    print('💰 ORDER_TOTALS_CALC_SERVICE: Total final: $amountTotal');
    print('💰 ORDER_TOTALS_CALC_SERVICE: Grupos de impuestos: ${taxGroupsList.length}');

    return OrderTotals(
      amountUntaxed: amountUntaxed,
      amountTax: totalTaxAmount,
      amountTotal: amountTotal,
      taxGroups: taxGroupsList,
    );
  }
}

