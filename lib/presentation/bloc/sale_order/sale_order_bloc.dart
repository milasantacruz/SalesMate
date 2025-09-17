import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/sale_order_repository.dart';
import 'sale_order_event.dart';
import 'sale_order_state.dart';

/// BLoC para manejar la lógica de Sale Orders
class SaleOrderBloc extends Bloc<SaleOrderEvent, SaleOrderState> {
  final SaleOrderRepository _saleOrderRepository;

  SaleOrderBloc(this._saleOrderRepository) : super(SaleOrderInitial()) {
    on<LoadSaleOrders>(_onLoadSaleOrders);
    on<RefreshSaleOrders>(_onRefreshSaleOrders);
    on<SearchAndFilterSaleOrders>(_onSearchAndFilterSaleOrders);
  }

  Future<void> _onLoadSaleOrders(
      LoadSaleOrders event, Emitter<SaleOrderState> emit) async {
    emit(SaleOrderLoading());
    try {
      await _saleOrderRepository.loadRecords();
      final saleOrders = _saleOrderRepository.latestRecords;
      if (saleOrders.isEmpty) {
        emit(const SaleOrderEmpty());
      } else {
        emit(SaleOrderLoaded(saleOrders));
      }
    } catch (e) {
      emit(SaleOrderError('Error cargando órdenes de venta: $e'));
    }
  }

  Future<void> _onRefreshSaleOrders(
      RefreshSaleOrders event, Emitter<SaleOrderState> emit) async {
    // Re-usa la lógica de _onLoadSaleOrders para refrescar
    await _onLoadSaleOrders(LoadSaleOrders(), emit);
  }

  Future<void> _onSearchAndFilterSaleOrders(
      SearchAndFilterSaleOrders event, Emitter<SaleOrderState> emit) async {
    emit(SaleOrderLoading());
    try {
      // Configurar los parámetros de búsqueda
      _saleOrderRepository.setSearchParams(
        searchTerm: event.searchTerm,
        state: event.state,
      );
      
      // Cargar los datos con los filtros aplicados
      await _saleOrderRepository.loadRecords();
      final saleOrders = _saleOrderRepository.latestRecords;
      if (saleOrders.isEmpty) {
        emit(const SaleOrderEmpty(
            message: 'No se encontraron resultados para los filtros aplicados'));
      } else {
        emit(SaleOrderLoaded(saleOrders));
      }
    } catch (e) {
      emit(SaleOrderError(
          'Error buscando y filtrando órdenes de venta: $e'));
    }
  }
}
