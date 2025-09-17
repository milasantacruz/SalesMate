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
    emit(PartnerLoading());
    try {
      await _partnerRepository.loadRecords();
      final partners = _partnerRepository.latestRecords;
      if (partners.isEmpty) {
        emit(const PartnerEmpty(message: 'No se encontraron partners'));
      } else {  
        emit(PartnerLoaded(partners));
      }
    } catch (e) {
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
