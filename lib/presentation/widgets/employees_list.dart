import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/employee/employee_bloc.dart';
import '../bloc/employee/employee_state.dart';
import '../bloc/employee/employee_event.dart';
import '../../data/models/employee_model.dart';

/// Widget que muestra la lista de empleados
class EmployeesList extends StatelessWidget {
  const EmployeesList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeeBloc, EmployeeState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context.read<EmployeeBloc>().add(RefreshEmployees());
            // Esperar un poco para que se complete la actualización
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: _buildContent(context, state),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, EmployeeState state) {
    print('👥 EMPLOYEES_LIST: _buildContent state: ${state.runtimeType}');
    switch (state.runtimeType) {
      case EmployeeInitial:
        return const _InitialWidget();
      
      case EmployeeLoading:
        return const _LoadingWidget();
      
      case EmployeeLoaded:
        final loadedState = state as EmployeeLoaded;
        return _EmployeeListView(employees: loadedState.employees);
      
      case EmployeeEmpty:
        final emptyState = state as EmployeeEmpty;
        return _EmptyWidget(message: emptyState.message);
      
      case EmployeeError:
        final errorState = state as EmployeeError;
        return _ErrorWidget(
          message: errorState.message,
          details: errorState.details,
        );
      
      case EmployeeOperationInProgress:
        final operationState = state as EmployeeOperationInProgress;
        return _OperationInProgressWidget(
          employees: operationState.employees,
          operation: operationState.operation,
        );
      
      case EmployeeSearchResult:
        final searchState = state as EmployeeSearchResult;
        return _SearchResultWidget(
          employees: searchState.employees,
          searchTerm: searchState.searchTerm,
          searchType: searchState.searchType,
        );
      
      case EmployeeFilteredByDepartment:
        final filteredState = state as EmployeeFilteredByDepartment;
        return _FilteredByDepartmentWidget(
          employees: filteredState.employees,
          departmentId: filteredState.departmentId,
        );
      
      default:
        return _ErrorWidget(
          message: 'Estado desconocido: ${state.runtimeType}',
        );
    }
  }
}

/// Widget para estado inicial
class _InitialWidget extends StatelessWidget {
  const _InitialWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Empleados',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Toca para cargar empleados',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Widget para estado de carga
class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Cargando empleados...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Widget para mostrar lista de empleados
class _EmployeeListView extends StatelessWidget {
  final List<Employee> employees;

  const _EmployeeListView({required this.employees});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        return _EmployeeCard(employee: employee);
      },
    );
  }
}

/// Card individual para mostrar un empleado
class _EmployeeCard extends StatelessWidget {
  final Employee employee;

  const _EmployeeCard({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'E',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          employee.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (employee.jobTitle != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.work_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      employee.jobTitle!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
            if (employee.departmentName != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.business_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      employee.departmentName!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
            if (employee.workEmail != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      employee.workEmail!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: employee.active
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.cancel, color: Colors.red),
        onTap: () {
          // TODO: Navegar a detalles del empleado
          print('👥 Empleado seleccionado: ${employee.name}');
        },
      ),
    );
  }
}

/// Widget para estado vacío
class _EmptyWidget extends StatelessWidget {
  final String message;

  const _EmptyWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              context.read<EmployeeBloc>().add(LoadEmployees());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

/// Widget para estado de error
class _ErrorWidget extends StatelessWidget {
  final String message;
  final String? details;

  const _ErrorWidget({required this.message, this.details});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(
                details!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.read<EmployeeBloc>().add(LoadEmployees());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget para operación en progreso
class _OperationInProgressWidget extends StatelessWidget {
  final List<Employee> employees;
  final String operation;

  const _OperationInProgressWidget({
    required this.employees,
    required this.operation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _EmployeeListView(employees: employees),
        Container(
          color: Colors.black54,
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(operation),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget para resultados de búsqueda
class _SearchResultWidget extends StatelessWidget {
  final List<Employee> employees;
  final String searchTerm;
  final String searchType;

  const _SearchResultWidget({
    required this.employees,
    required this.searchTerm,
    required this.searchType,
  });

  @override
  Widget build(BuildContext context) {
    String searchTypeText;
    switch (searchType) {
      case 'name':
        searchTypeText = 'nombre';
        break;
      case 'jobTitle':
        searchTypeText = 'puesto';
        break;
      default:
        searchTypeText = searchType;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Resultados para "$searchTerm" en $searchTypeText: ${employees.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () {
                  context.read<EmployeeBloc>().add(RefreshEmployees());
                },
                icon: const Icon(Icons.clear),
              ),
            ],
          ),
        ),
        Expanded(
          child: employees.isEmpty
              ? _EmptyWidget(message: 'No se encontraron empleados con "$searchTerm"')
              : _EmployeeListView(employees: employees),
        ),
      ],
    );
  }
}

/// Widget para empleados filtrados por departamento
class _FilteredByDepartmentWidget extends StatelessWidget {
  final List<Employee> employees;
  final int departmentId;

  const _FilteredByDepartmentWidget({
    required this.employees,
    required this.departmentId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.orange.shade50,
          child: Row(
            children: [
              const Icon(Icons.business, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Departamento ID $departmentId: ${employees.length} empleados',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () {
                  context.read<EmployeeBloc>().add(RefreshEmployees());
                },
                icon: const Icon(Icons.clear),
              ),
            ],
          ),
        ),
        Expanded(
          child: employees.isEmpty
              ? _EmptyWidget(message: 'No se encontraron empleados en este departamento')
              : _EmployeeListView(employees: employees),
        ),
      ],
    );
  }
}
