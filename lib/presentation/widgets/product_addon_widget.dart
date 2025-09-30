import 'package:flutter/material.dart';
import '../../data/models/product_model.dart';

/// Widget para mostrar un producto con controles de cantidad
class ProductAddonWidget extends StatelessWidget {
  final Product product;
  final double initialQuantity;
  final Function(double) onQuantityChanged;
  final VoidCallback onRemove;

  const ProductAddonWidget({
    super.key,
    required this.product,
    required this.initialQuantity,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showRemoveOptions(context),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
          children: [
            // Información del producto
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (product.defaultCode != null)
                    Text(
                      'Código: ${product.defaultCode}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '\$${product.listPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChip(),
                    ],
                  ),
                ],
              ),
            ),
            
            // Controles de cantidad (vertical)
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Text(
                    'Cantidad',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Botón más (arriba)
                      IconButton(
                        onPressed: () => onQuantityChanged(initialQuantity + 1),
                        icon: const Icon(Icons.add_circle_outline),
                        color: Colors.green,
                        iconSize: 24,
                      ),

                      // Cantidad actual (centro)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          initialQuantity.toInt().toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      // Botón menos (abajo)
                      IconButton(
                        onPressed: initialQuantity > 1 
                            ? () => onQuantityChanged(initialQuantity - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: initialQuantity > 1 ? Colors.red : Colors.grey,
                        iconSize: 24,
                      ),
                    ],
                  ),

                  // Subtotal de la línea
                  const SizedBox(height: 4),
                  Text(
                    'Subtotal: \$${(product.listPrice * initialQuantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  void _showRemoveOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opciones',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Eliminar producto'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onRemove();
                  },
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeChip() {
    Color chipColor;
    String chipText;
    
    switch (product.type) {
      case 'product':
        chipColor = Colors.blue.shade100;
        chipText = 'Producto';
        break;
      case 'service':
        chipColor = Colors.green.shade100;
        chipText = 'Servicio';
        break;
      case 'consu':
        chipColor = Colors.orange.shade100;
        chipText = 'Consumible';
        break;
      default:
        chipColor = Colors.grey.shade200;
        chipText = product.type;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        chipText,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

