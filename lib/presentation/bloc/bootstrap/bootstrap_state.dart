import 'package:equatable/equatable.dart';
import '../../../core/bootstrap/bootstrap_state.dart' as core;

abstract class UiBootstrapState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UiBootstrapInitial extends UiBootstrapState {}

class UiBootstrapInProgress extends UiBootstrapState {
  final core.BootstrapState state;
  UiBootstrapInProgress(this.state);

  @override
  List<Object?> get props => [state];
}

class UiBootstrapCompleted extends UiBootstrapState {
  final core.BootstrapState state;
  UiBootstrapCompleted(this.state);

  @override
  List<Object?> get props => [state];
}

class UiBootstrapFailed extends UiBootstrapState {
  final String message;
  UiBootstrapFailed(this.message);

  @override
  List<Object?> get props => [message];
}


