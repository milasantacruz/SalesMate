import 'package:equatable/equatable.dart';
import '../../../core/bootstrap/bootstrap_state.dart';

class BootstrapEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class BootstrapStarted extends BootstrapEvent {
  final int pageSize;
  BootstrapStarted({this.pageSize = 200});
  
  @override
  List<Object?> get props => [pageSize];
}

class BootstrapProgressUpdate extends BootstrapEvent {
  final BootstrapState progressState;
  
  BootstrapProgressUpdate(this.progressState);
  
  @override
  List<Object?> get props => [progressState];
}

class BootstrapDismissed extends BootstrapEvent {}


