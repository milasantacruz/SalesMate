import 'package:flutter/material.dart';

/// Widget para mostrar información de auditoría de un registro
class AuditWidget extends StatelessWidget {
  final String? userName;
  final int? createUid;
  final String? createUserName;
  final String? createDate;
  final int? writeUid;
  final String? writeUserName;
  final String? writeDate;
  final String? currentState;
  final String? stateDescription;
  final Color? stateColor;

  const AuditWidget({
    super.key,
    this.userName,
    required this.createUid,
    this.createUserName,
    this.createDate,
    this.writeUid,
    this.writeUserName,
    this.writeDate,
    this.currentState,
    this.stateDescription,
    this.stateColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información de Auditoría',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          
          // Usuario responsable de la operación
          if (userName != null) ...[
            _buildAuditRow(
              context: context,
              icon: Icons.person,
              label: 'Usuario Responsable:',
              value: userName!,
            ),
            const SizedBox(height: 4),
          ],
          
          // Información de creación
          _buildAuditRow(
            context: context,
            icon: Icons.add_circle_outline,
            label: 'Creado por:',
            value: createUserName ?? 'Usuario $createUid',
            dateColor: Colors.green,
            timestamp: createDate,
          ),
          const SizedBox(height: 4),
          
          // Información de última modificación
          if (writeUid != null && writeDate != null) ...[
            _buildAuditRow(
              context: context,
              icon: Icons.edit_outlined,
              label: 'Última modificación:',
              value: writeUserName ?? 'Usuario $writeUid',
              dateColor: Colors.orange,
              timestamp: writeDate!,
            ),
          ],
          
          // Estado actual (si se proporciona)
          if (currentState != null) ...[
            const SizedBox(height: 4),
            _buildAuditRow(
              context: context,
              icon: Icons.info_outline,
              label: 'Estado actual:',
              value: stateDescription ?? _getDefaultStateDescription(currentState!),
              dateColor: stateColor ?? _getDefaultStateColor(currentState!),
            ),
          ],
        ],
      ),
    );
  }

  /// Construye una fila de información de auditoría
  Widget _buildAuditRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    Color? dateColor,
    String? timestamp,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall,
              children: [
              TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              TextSpan(
                  text: value,
                  style: TextStyle(
                    color: dateColor ?? Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (timestamp != null) ...[
                  const TextSpan(text: '\nActualizado: '),
                  TextSpan(
                    text: _formatDateTime(timestamp),
                    style: TextStyle(
                      color: dateColor ?? Colors.grey[700],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Obtiene descripción del estado en español
  String _getDefaultStateDescription(String state) {
    switch (state) {
      case 'draft':
        return 'Borrador';
      case 'sent':
        return 'Cotización Enviada';
      case 'sale':
        return 'Confirmada';
      case 'done':
        return 'Entregada';
      case 'cancel':
        return 'Cancelada';
      default:
        return state.toUpperCase();
    }
  }

  /// Obtiene color según el estado
  Color _getDefaultStateColor(String state) {
    switch (state) {
      case 'draft':
        return Colors.orange;
      case 'sent':
        return Colors.blue;
      case 'sale':
        return Colors.green;
      case 'done':
        return Colors.green[700]!;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Formatea fecha y hora para auditoría
  String _formatDateTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString.length > 10 ? dateString.substring(0, 10) : dateString;
    }
  }
}
