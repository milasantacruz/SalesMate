import 'package:equatable/equatable.dart';
import '../../data/models/partner_model.dart';

/// Estados base para el manejo de partners
abstract class PartnerState extends Equatable {
  const PartnerState();
  @override
  List<Object> get props => [];
}

/// Estado inicial
class PartnerInitial extends PartnerState {}

/// Estado de carga
class PartnerLoading extends PartnerState {}

/// Estado cuando se han cargado los partners exitosamente
class PartnerLoaded extends PartnerState {
  final List<Partner> partners;
  
  const PartnerLoaded(this.partners);
  
  @override
  List<Object> get props => [partners];
}

/// Estado cuando no hay partners para mostrar
class PartnerEmpty extends PartnerState {
  final String message;
  
  const PartnerEmpty({this.message = 'No se encontraron partners'});
  
  @override
  List<Object> get props => [message];
}

/// Estado de error
class PartnerError extends PartnerState {
  final String message;
  final String? details;
  
  const PartnerError(this.message, {this.details});
  
  @override
  List<Object> get props => [message, details ?? ''];
}

/// Estado durante operaciones específicas (crear, actualizar, eliminar)
class PartnerOperationInProgress extends PartnerState {
  final List<Partner> partners; // Mantener lista actual
  final String operation;
  
  const PartnerOperationInProgress(this.partners, this.operation);
  
  @override
  List<Object> get props => [partners, operation];
}

/// Estado cuando se muestran resultados de búsqueda
class PartnerSearchResult extends PartnerState {
  final List<Partner> partners;
  final String searchTerm;
  
  const PartnerSearchResult(this.partners, this.searchTerm);
  
  @override
  List<Object> get props => [partners, searchTerm];
}
