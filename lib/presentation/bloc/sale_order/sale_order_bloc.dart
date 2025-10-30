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
    on<CreateSaleOrder>(_onCreateSaleOrder);
    on<UpdateOrderState>(_onUpdateOrderState);
    on<CalculateOrderTotals>(_onCalculateOrderTotals);
    on<ClearTotalsCache>(_onClearTotalsCache);
    on<LoadSaleOrdersByPartner>(_onLoadSaleOrdersByPartner);
    on<LoadSaleOrderById>(_onLoadSaleOrderById);
    on<UpdateSaleOrder>(_onUpdateSaleOrder);
    on<SendQuotation>(_onSendQuotation);
  }

  Future<void> _onLoadSaleOrders(
      LoadSaleOrders event, Emitter<SaleOrderState> emit) async {
    emit(SaleOrderLoading());
    try {
      await _saleOrderRepository.fetchRecords();
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
      await _saleOrderRepository.fetchRecords();
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

  Future<void> _onCreateSaleOrder(
      CreateSaleOrder event, Emitter<SaleOrderState> emit) async {
    emit(SaleOrderCreating());
    try {
      final localId = await _saleOrderRepository.createSaleOrder(event.orderData);
      
      // Emitir estado de éxito
      emit(SaleOrderCreated(
        orderId: localId,
        orderData: event.orderData,
      ));
        
      // LIMPIAR FILTROS para mostrar todas las órdenes incluyendo la nueva
      _saleOrderRepository.setSearchParams(
        searchTerm: '',
        state: null, // ← Limpiar filtro de estado
      );
      
      // Recargar la lista de órdenes para mostrar la nueva orden
      await _saleOrderRepository.fetchRecords();
      final saleOrders = _saleOrderRepository.latestRecords;
      if (saleOrders.isEmpty) {
        emit(const SaleOrderEmpty());
      } else {
        emit(SaleOrderLoaded(saleOrders));
      }
    } catch (e) {
      emit(SaleOrderError('Error creando orden de venta: $e'));
    }
  }

  Future<void> _onUpdateOrderState(
      UpdateOrderState event, Emitter<SaleOrderState> emit) async {
    emit(SaleOrderUpdating(orderId: event.orderId));
    try {
      final success = await _saleOrderRepository.updateOrderState(
        event.orderId, 
        event.newState,
      );
      
      if (success) {
        // Emitir estado de éxito
        emit(SaleOrderUpdated(
          orderId: event.orderId,
          newState: event.newState,
        ));
        
        // Recargar la lista de órdenes para mostrar los cambios
        await _saleOrderRepository.fetchRecords();
        final saleOrders = _saleOrderRepository.latestRecords;
        if (saleOrders.isEmpty) {
          emit(const SaleOrderEmpty());
        } else {
          emit(SaleOrderLoaded(saleOrders));
        }
      } else {
        emit(SaleOrderError('Error actualizando estado de la orden'));
      }
    } catch (e) {
      emit(SaleOrderError('Error actualizando orden: $e'));
    }
  }

  Future<void> _onCalculateOrderTotals(
    CalculateOrderTotals event,
    Emitter<SaleOrderState> emit,
  ) async {
    print('🧮 SALE_ORDER_BLOC: _onCalculateOrderTotals called');
    print('🧮 SALE_ORDER_BLOC: partnerId: ${event.partnerId}');
    print('🧮 SALE_ORDER_BLOC: orderLines.length: ${event.orderLines.length}');
    
    emit(SaleOrderCalculatingTotals());
    print('🧮 SALE_ORDER_BLOC: Emitted SaleOrderCalculatingTotals');
    
    try {
      print('🧮 SALE_ORDER_BLOC: Calling calculateOrderTotals...');
      final totals = await _saleOrderRepository.calculateOrderTotals(
        partnerId: event.partnerId,
        orderLines: event.orderLines,
      );
      
      print('🧮 SALE_ORDER_BLOC: Totals calculated successfully: ${totals.amountTotal}');
      emit(SaleOrderTotalsCalculated(totals: totals));
      print('🧮 SALE_ORDER_BLOC: Emitted SaleOrderTotalsCalculated');
    } catch (e) {
      print('❌ SALE_ORDER_BLOC: Error calculating totals: $e');
      emit(SaleOrderError('Error calculando totales: $e'));
    }
  }

  Future<void> _onClearTotalsCache(
    ClearTotalsCache event,
    Emitter<SaleOrderState> emit,
  ) async {
    _saleOrderRepository.clearTotalsCache();
    // No emitir estado, solo limpiar cache
  }

  Future<void> _onLoadSaleOrdersByPartner(
    LoadSaleOrdersByPartner event,
    Emitter<SaleOrderState> emit,
  ) async {
    emit(SaleOrderLoading());
    try {
      final orders = await _saleOrderRepository.getOrdersByPartner(event.partnerId);
      emit(SaleOrdersLoadedByPartner(orders: orders, partnerId: event.partnerId));
    } catch (e) {
      emit(SaleOrderError('Error cargando órdenes del cliente: $e'));
    }
  }

  Future<void> _onLoadSaleOrderById(
    LoadSaleOrderById event,
    Emitter<SaleOrderState> emit,
  ) async {
    print('📥 SALE_ORDER_BLOC: _onLoadSaleOrderById start - orderId=${event.orderId}');
    emit(SaleOrderLoading());
    try {
      final order = await _saleOrderRepository.getOrderById(event.orderId);
      if (order != null) {
        print('📤 SALE_ORDER_BLOC: _onLoadSaleOrderById success - emitting LoadedById (id=${order.id}, lines=${order.orderLines.length})');
        emit(SaleOrderLoadedById(order: order));
      } else {
        print('❌ SALE_ORDER_BLOC: _onLoadSaleOrderById not found');
        emit(SaleOrderError('Orden no encontrada'));
      }
    } catch (e) {
      print('❌ SALE_ORDER_BLOC: _onLoadSaleOrderById error: $e');
      emit(SaleOrderError('Error cargando orden: $e'));
    }
  }

  Future<void> _onUpdateSaleOrder(
    UpdateSaleOrder event,
    Emitter<SaleOrderState> emit,
  ) async {
    print('🛒 SALE_ORDER_BLOC: _onUpdateSaleOrder called');
    emit(SaleOrderUpdating(orderId: event.orderId));
    try {
      final success = await _saleOrderRepository.updateOrder(
        event.orderId,
        event.orderData,
      );
      
      if (success) {
        print('🛒 SALE_ORDER_BLOC: Order updated successfully');
        // Recargar la orden actualizada
        final updatedOrder = await _saleOrderRepository.getOrderById(event.orderId);
        if (updatedOrder != null) {
          emit(SaleOrderLoadedById(order: updatedOrder));
        } else {
          emit(SaleOrderError('Error recargando orden actualizada'));
        }
      } else {
        emit(SaleOrderError('Error actualizando orden'));
      }
    } catch (e) {
      emit(SaleOrderError('Error actualizando orden: $e'));
    }
  }

  Future<void> _onSendQuotation(
      SendQuotation event, Emitter<SaleOrderState> emit) async {
    emit(SaleOrderSending(orderId: event.orderId));
    try {
      final success = await _saleOrderRepository.sendQuotation(event.orderId);
      
      if (success) {
        emit(SaleOrderSent(orderId: event.orderId));
        
        // Recargar la orden actualizada
        print('🔄 SALE_ORDER_BLOC: Recargando orden después de enviar cotización...');
        final updatedOrder = await _saleOrderRepository.getOrderById(event.orderId);
        if (updatedOrder != null) {
          print('✅ SALE_ORDER_BLOC: Orden recargada - Estado: ${updatedOrder.state}');
          print('✅ SALE_ORDER_BLOC: Datos orden recargada: id=${updatedOrder.id}, name=${updatedOrder.name}, state=${updatedOrder.state}');
          emit(SaleOrderLoadedById(order: updatedOrder));
        } else {
          print('❌ SALE_ORDER_BLOC: No se pudo obtener la orden actualizada');
          emit(SaleOrderError('Error recargando orden enviada'));
        }
      } else {
        print('❌ SALE_ORDER_BLOC: sendQuotation retornó false');
        emit(SaleOrderError('Error enviando cotización'));
      }
    } catch (e) {
      emit(SaleOrderError('Error enviando cotización: $e'));
    }
  }
}


