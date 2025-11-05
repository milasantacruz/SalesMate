import '../../data/repositories/tax_repository.dart';

/// Resultado del cálculo de impuestos para una línea de orden
class TaxLineCalculation {
  final double baseAmount;
  final double taxAmount;
  final double totalAmount;
  final List<TaxLineDetail> taxDetails; // Por cada impuesto aplicado

  TaxLineCalculation({
    required this.baseAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.taxDetails,
  });

  @override
  String toString() =>
      'TaxLineCalculation(base: $baseAmount, tax: $taxAmount, total: $totalAmount, details: ${taxDetails.length})';
}

/// Detalle de un impuesto aplicado
class TaxLineDetail {
  final int taxId;
  final String taxName;
  final double amount;
  final double base;
  final double? percentage; // Porcentaje del impuesto (null si es fijo)

  TaxLineDetail({
    required this.taxId,
    required this.taxName,
    required this.amount,
    required this.base,
    this.percentage,
  });

  @override
  String toString() =>
      'TaxLineDetail(id: $taxId, name: $taxName, amount: $amount, base: $base, percentage: $percentage)';
}

/// Servicio para calcular impuestos localmente usando datos cacheados
class TaxCalculationService {
  final TaxRepository _taxRepository;

  TaxCalculationService(this._taxRepository);

  /// Calcula impuestos para una línea de orden
  ///
  /// [baseAmount] Monto base sobre el cual calcular impuestos
  /// [taxIds] Lista de IDs de impuestos a aplicar
  /// [companyId] ID de la empresa/company para filtrar impuestos
  ///
  /// Retorna [TaxLineCalculation] con el resultado del cálculo
  TaxLineCalculation calculateTaxesForLine({
    required double baseAmount,
    required List<int> taxIds,
    required int companyId,
  }) {
    print('💰 TAX_CALC_SERVICE: Calculando impuestos para línea');
    print('💰 TAX_CALC_SERVICE: Base amount: $baseAmount');
    print('💰 TAX_CALC_SERVICE: Tax IDs: $taxIds');
    print('💰 TAX_CALC_SERVICE: Company ID: $companyId');

    // Si no hay impuestos, retornar cálculo vacío
    if (taxIds.isEmpty) {
      print('ℹ️ TAX_CALC_SERVICE: No hay impuestos - retornando cálculo vacío');
      return TaxLineCalculation(
        baseAmount: baseAmount,
        taxAmount: 0.0,
        totalAmount: baseAmount,
        taxDetails: [],
      );
    }

    double totalTaxAmount = 0.0;
    final List<TaxLineDetail> taxDetails = [];

    // Iterar sobre cada impuesto
    for (final taxId in taxIds) {
      try {
        // Obtener impuesto desde cache
        final tax = _taxRepository.getTaxById(taxId, companyId);

        if (tax == null) {
          print('⚠️ TAX_CALC_SERVICE: Impuesto $taxId no encontrado en cache - saltando');
          continue;
        }

        print('✅ TAX_CALC_SERVICE: Impuesto encontrado: ${tax.name} (${tax.amountType}: ${tax.amount})');

        // Calcular monto del impuesto según su tipo
        double taxAmount = 0.0;
        double taxBase = baseAmount; // Base sobre la cual se aplica el impuesto

        switch (tax.amountType) {
          case 'percent':
            // Impuesto porcentual: amount es el porcentaje (ej: 19 para 19%)
            taxAmount = baseAmount * (tax.amount / 100);
            print('💰 TAX_CALC_SERVICE: Impuesto porcentual: ${tax.amount}% de $baseAmount = $taxAmount');
            break;

          case 'fixed':
            // Impuesto fijo: amount es el monto fijo
            taxAmount = tax.amount;
            print('💰 TAX_CALC_SERVICE: Impuesto fijo: $taxAmount');
            break;

          case 'group':
            // TODO: Implementar lógica de grupo de impuestos si es necesario
            // Por ahora, tratarlo como porcentual
            print('⚠️ TAX_CALC_SERVICE: Impuesto de tipo "group" - usando como porcentual');
            taxAmount = baseAmount * (tax.amount / 100);
            break;

          case 'division':
            // TODO: Implementar lógica de división si es necesario
            // Por ahora, tratarlo como porcentual
            print('⚠️ TAX_CALC_SERVICE: Impuesto de tipo "division" - usando como porcentual');
            taxAmount = baseAmount * (tax.amount / 100);
            break;

          default:
            print('⚠️ TAX_CALC_SERVICE: Tipo de impuesto desconocido: ${tax.amountType} - usando como porcentual');
            taxAmount = baseAmount * (tax.amount / 100);
            break;
        }

        // Como priceInclude siempre es false según requerimientos,
        // no ajustamos la base
        // Si priceInclude fuera true, habría que ajustar:
        // taxBase = baseAmount - taxAmount

        // Acumular impuesto
        totalTaxAmount += taxAmount;

        // Agregar detalle
        taxDetails.add(TaxLineDetail(
          taxId: tax.id,
          taxName: tax.name,
          amount: taxAmount,
          base: taxBase,
          percentage: tax.isPercent ? tax.amount : null, // Solo porcentaje si es tipo percent
        ));

        print('✅ TAX_CALC_SERVICE: Impuesto ${tax.name} calculado: $taxAmount');
      } catch (e) {
        print('❌ TAX_CALC_SERVICE: Error calculando impuesto $taxId: $e');
        // Continuar con el siguiente impuesto
      }
    }

    // Calcular total
    final totalAmount = baseAmount + totalTaxAmount;

    print('✅ TAX_CALC_SERVICE: Cálculo completado');
    print('💰 TAX_CALC_SERVICE: Base: $baseAmount');
    print('💰 TAX_CALC_SERVICE: Impuestos: $totalTaxAmount');
    print('💰 TAX_CALC_SERVICE: Total: $totalAmount');
    print('💰 TAX_CALC_SERVICE: Detalles: ${taxDetails.length} impuestos aplicados');

    return TaxLineCalculation(
      baseAmount: baseAmount,
      taxAmount: totalTaxAmount,
      totalAmount: totalAmount,
      taxDetails: taxDetails,
    );
  }
}
