import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/models/partner_model.dart';
import 'partner_event.dart';
import 'partner_state.dart';

/// BLoC para manejar la lógica de partners
class PartnerBloc extends Bloc<PartnerEvent, PartnerState> {
  final PartnerRepository _partnerRepository;
  StreamSubscription<List<Partner>>? _partnersSubscription;

  PartnerBloc(this._partnerRepository) : super(PartnerInitial()) {
    on<LoadPartners>(_onLoadPartners);
    on<RefreshPartners>(_onRefreshPartners);
    on<CreatePartner>(_onCreatePartner);
    on<UpdatePartner>(_onUpdatePartner);
    on<DeletePartner>(_onDeletePartner);
    on<SearchPartnersByName>(_onSearchPartnersByName);
    on<SearchPartnersByEmail>(_onSearchPartnersByEmail);
    on<PartnersUpdated>(_onPartnersUpdated);
    
    // Suscribirse al stream de partners
    _subscribeToPartners();
  }

  /// Inicializar con los datos actuales del repositorio
  void _subscribeToPartners() {
    // Como latestRecords es una List, no un Stream, 
    // simplemente obtenemos los datos actuales
    final currentPartners = _partnerRepository.latestRecords;
    if (currentPartners.isNotEmpty) {
      add(PartnersUpdated(currentPartners));
    }
  }

  /// Maneja la carga inicial de partners
  Future<void> _onLoadPartners(LoadPartners event, Emitter<PartnerState> emit) async {
    print('📋 Cargando partners...');
    emit(PartnerLoading());
    
    try {
      // Disparar la carga de datos
      _partnerRepository.loadRecords();
      
      // El estado se actualizará automáticamente a través del stream
      // Si no hay datos después de un tiempo, mostrar empty
      await Future.delayed(const Duration(seconds: 2));
      
      if (state is PartnerLoading) {
        emit(const PartnerEmpty(message: 'No se encontraron partners'));
      }
    } catch (e) {
      print('❌ Error cargando partners: $e');
      emit(PartnerError('Error cargando partners: $e'));
    }
  }

  /// Maneja la actualización/refresh de partners
  Future<void> _onRefreshPartners(RefreshPartners event, Emitter<PartnerState> emit) async {
    print('🔄 Refrescando partners...');
    
    try {
      // Recargar datos del repositorio
      _partnerRepository.loadRecords();
      
      // Mostrar loading solo si no tenemos datos previos
      if (state is PartnerInitial || state is PartnerEmpty || state is PartnerError) {
        emit(PartnerLoading());
      }
    } catch (e) {
      print('❌ Error refrescando partners: $e');
      emit(PartnerError('Error refrescando partners: $e'));
    }
  }

  /// Maneja la creación de un nuevo partner
  Future<void> _onCreatePartner(CreatePartner event, Emitter<PartnerState> emit) async {
    print('➕ Creando partner: ${event.partner.name}');
    
    // Mostrar estado de operación en progreso
    final currentPartners = _getCurrentPartners();
    emit(PartnerOperationInProgress(currentPartners, 'Creando partner...'));
    
    try {
      await _partnerRepository.createPartner(event.partner);
      print('✅ Partner creado exitosamente');
      
      // Recargar datos
      _partnerRepository.loadRecords();
    } catch (e) {
      print('❌ Error creando partner: $e');
      emit(PartnerError('Error creando partner: $e'));
    }
  }

  /// Maneja la actualización de un partner
  Future<void> _onUpdatePartner(UpdatePartner event, Emitter<PartnerState> emit) async {
    print('✏️ Actualizando partner: ${event.partner.name}');
    
    final currentPartners = _getCurrentPartners();
    emit(PartnerOperationInProgress(currentPartners, 'Actualizando partner...'));
    
    try {
      await _partnerRepository.updatePartner(event.partner);
      print('✅ Partner actualizado exitosamente');
      
      // Recargar datos
      _partnerRepository.loadRecords();
    } catch (e) {
      print('❌ Error actualizando partner: $e');
      emit(PartnerError('Error actualizando partner: $e'));
    }
  }

  /// Maneja la eliminación de un partner
  Future<void> _onDeletePartner(DeletePartner event, Emitter<PartnerState> emit) async {
    print('🗑️ Eliminando partner ID: ${event.partnerId}');
    
    final currentPartners = _getCurrentPartners();
    emit(PartnerOperationInProgress(currentPartners, 'Eliminando partner...'));
    
    try {
      await _partnerRepository.deletePartner(event.partnerId);
      print('✅ Partner eliminado exitosamente');
      
      // Recargar datos
      _partnerRepository.loadRecords();
    } catch (e) {
      print('❌ Error eliminando partner: $e');
      emit(PartnerError('Error eliminando partner: $e'));
    }
  }

  /// Maneja la búsqueda de partners por nombre
  Future<void> _onSearchPartnersByName(SearchPartnersByName event, Emitter<PartnerState> emit) async {
    print('🔍 Buscando partners por nombre: ${event.searchTerm}');
    
    if (event.searchTerm.trim().isEmpty) {
      // Si la búsqueda está vacía, recargar todos los partners
      add(RefreshPartners());
      return;
    }
    
    emit(PartnerLoading());
    
    try {
      final results = await _partnerRepository.searchByName(event.searchTerm);
      
      if (results.isEmpty) {
        emit(PartnerSearchResult([], event.searchTerm));
      } else {
        emit(PartnerSearchResult(results, event.searchTerm));
      }
    } catch (e) {
      print('❌ Error buscando partners: $e');
      emit(PartnerError('Error buscando partners: $e'));
    }
  }

  /// Maneja la búsqueda de partners por email
  Future<void> _onSearchPartnersByEmail(SearchPartnersByEmail event, Emitter<PartnerState> emit) async {
    print('📧 Buscando partners por email: ${event.email}');
    
    if (event.email.trim().isEmpty) {
      add(RefreshPartners());
      return;
    }
    
    emit(PartnerLoading());
    
    try {
      // TODO: Implementar búsqueda por email en el repositorio
      final allPartners = _partnerRepository.currentPartners;
      final results = allPartners.where((partner) => 
        partner.email?.toLowerCase().contains(event.email.toLowerCase()) == true
      ).toList();
      
      emit(PartnerSearchResult(results, event.email));
    } catch (e) {
      print('❌ Error buscando partners por email: $e');
      emit(PartnerError('Error buscando partners por email: $e'));
    }
  }

  /// Maneja las actualizaciones del stream de partners
  Future<void> _onPartnersUpdated(PartnersUpdated event, Emitter<PartnerState> emit) async {
    print('🔄 Partners actualizados: ${event.partners.length} items');
    
    if (event.partners.isEmpty) {
      emit(const PartnerEmpty());
    } else {
      emit(PartnerLoaded(event.partners));
    }
  }

  /// Obtiene la lista actual de partners del estado
  List<Partner> _getCurrentPartners() {
    final currentState = state;
    if (currentState is PartnerLoaded) {
      return currentState.partners;
    } else if (currentState is PartnerSearchResult) {
      return currentState.partners;
    } else if (currentState is PartnerOperationInProgress) {
      return currentState.partners;
    }
    return [];
  }

  @override
  Future<void> close() {
    _partnersSubscription?.cancel();
    return super.close();
  }
}
