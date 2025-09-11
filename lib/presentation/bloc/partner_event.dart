import 'package:equatable/equatable.dart';
import '../../data/models/partner_model.dart';

/// Eventos base para el manejo de partners
abstract class PartnerEvent extends Equatable {
  const PartnerEvent();
  @override
  List<Object> get props => [];
}

/// Evento para cargar la lista de partners
class LoadPartners extends PartnerEvent {}

/// Evento para refrescar la lista de partners
class RefreshPartners extends PartnerEvent {}

/// Evento para crear un nuevo partner
class CreatePartner extends PartnerEvent {
  final Partner partner;
  
  const CreatePartner(this.partner);
  
  @override
  List<Object> get props => [partner];
}

/// Evento para actualizar un partner existente
class UpdatePartner extends PartnerEvent {
  final Partner partner;
  
  const UpdatePartner(this.partner);
  
  @override
  List<Object> get props => [partner];
}

/// Evento para eliminar un partner
class DeletePartner extends PartnerEvent {
  final int partnerId;
  
  const DeletePartner(this.partnerId);
  
  @override
  List<Object> get props => [partnerId];
}

/// Evento para buscar partners por nombre
class SearchPartnersByName extends PartnerEvent {
  final String searchTerm;
  
  const SearchPartnersByName(this.searchTerm);
  
  @override
  List<Object> get props => [searchTerm];
}

/// Evento para buscar partners por email
class SearchPartnersByEmail extends PartnerEvent {
  final String email;
  
  const SearchPartnersByEmail(this.email);
  
  @override
  List<Object> get props => [email];
}

/// Evento interno cuando se actualizan los partners desde el stream
class PartnersUpdated extends PartnerEvent {
  final List<Partner> partners;
  
  const PartnersUpdated(this.partners);
  
  @override
  List<Object> get props => [partners];
}
