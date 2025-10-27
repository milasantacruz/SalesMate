import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/partner_repository.dart';
import 'partner_event.dart';
import 'partner_state.dart';

/// BLoC para manejar la lógica de partners
class PartnerBloc extends Bloc<PartnerEvent, PartnerState> {
  final PartnerRepository _partnerRepository;

  PartnerBloc(this._partnerRepository) : super(PartnerInitial()) {
    on<LoadPartners>(_onLoadPartners);
    on<RefreshPartners>(_onRefreshPartners);
  }

  /// Maneja la carga inicial de partners
  Future<void> _onLoadPartners(LoadPartners event, Emitter<PartnerState> emit) async {
    print('🔍 DIAGNÓSTICO PARTNER_BLOC: _onLoadPartners llamado');
    emit(PartnerLoading());
    try {
      print('🔍 DIAGNÓSTICO PARTNER_BLOC: Llamando loadRecords()...');
      await _partnerRepository.loadRecords();
      final partners = _partnerRepository.latestRecords;
      print('🔍 DIAGNÓSTICO PARTNER_BLOC: latestRecords.length: ${partners.length}');
      
      if (partners.isEmpty) {
        print('🔍 DIAGNÓSTICO PARTNER_BLOC: partners.isEmpty = true, emitiendo PartnerEmpty');
        emit(const PartnerEmpty(message: 'No se encontraron partners'));
      } else {
        print('🔍 DIAGNÓSTICO PARTNER_BLOC: partners.isEmpty = false, emitiendo PartnerLoaded con ${partners.length} partners');
        emit(PartnerLoaded(partners));
      }
    } catch (e) {
      print('🔍 DIAGNÓSTICO PARTNER_BLOC: Error capturado: $e');
      emit(PartnerError('Error cargando partners: $e'));
    }
  }

  /// Maneja la actualización/refresh de partners
  Future<void> _onRefreshPartners(
      RefreshPartners event, Emitter<PartnerState> emit) async {
    // Reutilizamos la lógica de carga, que ya emite el estado Loading.
    await _onLoadPartners(LoadPartners(), emit);
  }
}
