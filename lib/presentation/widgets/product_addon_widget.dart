import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/product_model.dart';

/// Widget para mostrar un producto con controles de cantidad
class ProductAddonWidget extends StatefulWidget {
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
  State<ProductAddonWidget> createState() => _ProductAddonWidgetState();
}

class _ProductAddonWidgetState extends State<ProductAddonWidget> {
  late final TextEditingController _qtyController;
  final FocusNode _qtyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: _formatQuantity(widget.initialQuantity));
  }

  @override
  void didUpdateWidget(covariant ProductAddonWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuantity != widget.initialQuantity && !_qtyFocusNode.hasFocus) {
      _qtyController.text = _formatQuantity(widget.initialQuantity);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _qtyFocusNode.dispose();
    super.dispose();
  }

  String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  double _parseControllerQuantity() {
    final text = _qtyController.text.replaceAll(',', '.');
    final parsed = double.tryParse(text);
    if (parsed == null) return 0;
    if (parsed < 0) return 0;
    return parsed;
  }

  void _increment() {
    final current = _parseControllerQuantity();
    final next = current + 1.0;
    _qtyController.text = next.toInt().toString();
    widget.onQuantityChanged(next);
    setState(() {});
  }

  void _decrement() {
    final current = _parseControllerQuantity();
    final next = current > 0.0 ? current - 1.0 : 0.0;
    if (next != current) {
      _qtyController.text = next.toInt().toString();
      widget.onQuantityChanged(next);
      setState(() {});
    }
  }

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
                    widget.product.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (widget.product.defaultCode != null)
                    Text(
                      'Código: ${widget.product.defaultCode}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '\$${_formatPrice(widget.product.listPrice)}',
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
                        onPressed: _increment,
                        icon: const Icon(Icons.add_circle_outline),
                        color: Colors.green,
                        iconSize: 24,
                      ),

                      // Campo de texto para cantidad (centro)
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _qtyController,
                          focusNode: _qtyFocusNode,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onTap: () {
                            _qtyController.selection = TextSelection(baseOffset: 0, extentOffset: _qtyController.text.length);
                          },
                          onChanged: (val) {
                            final intQty = int.tryParse(val);
                            if (intQty != null && intQty >= 0) {
                              widget.onQuantityChanged(intQty.toDouble());
                            }
                            setState(() {});
                          },
                          onSubmitted: (val) {
                            final intQty = int.tryParse(val) ?? 0;
                            final int normalized = intQty < 0 ? 0 : intQty;
                            _qtyController.text = normalized.toString();
                            widget.onQuantityChanged(normalized.toDouble());
                          },
                        ),
                      ),

                      // Botón menos (abajo)
                      IconButton(
                        onPressed: _decrement,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: _parseControllerQuantity() > 0.0 ? Colors.red : Colors.grey,
                        iconSize: 24,
                      ),
                    ],
                  ),

                  // Subtotal de la línea
                  const SizedBox(height: 4),
                  Text(
                    'Subtotal: ${_fmtCurrency(widget.product.listPrice * (_parseControllerQuantity()))}',
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

  /// Formatea un número como moneda chilena con puntos de mil
  /// Ejemplo: 124368 -> "$124.368"
  String _fmtCurrency(num value) {
    int n = value.round();
    final s = n.toString();
    final sb = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      sb.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) sb.write('.');
    }
    final rev = sb.toString().split('').reversed.join();
    return '\$$rev';
  }

  /// Formatea el precio unitario con formato de miles (sin decimales)
  /// Ejemplo: 31092.0 -> "31.092"
  String _formatPrice(double price) {
    // Validar que el precio sea un número válido
    if (price.isNaN || price.isInfinite || price < 0) {
      return '0';
    }
    
    // Redondear a entero y convertir a string (sin decimales)
    final int n = price.round();
    final s = n.toString();
    
    // Si el string está vacío, retornar "0"
    if (s.isEmpty) return '0';
    
    // Construir el string con puntos de mil desde el final
    final sb = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      sb.write(s[i]);
      count++;
      // Agregar punto cada 3 dígitos, excepto al inicio
      if (count % 3 == 0 && i != 0) {
        sb.write('.');
      }
    }
    
    // Invertir el string resultante para obtener el formato correcto
    final rev = sb.toString().split('').reversed.join();
    return rev;
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
                    widget.onRemove();
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

    // Nueva lógica: servicio (type=service, is_storable=false),
    // consumible (type=consu, is_storable=false),
    // producto (type=consu, is_storable=true)
    if (widget.product.type == 'service' && widget.product.isStorable == false) {
      chipColor = Colors.green.shade100;
      chipText = 'Servicio';
    } else if (widget.product.type == 'consu' && widget.product.isStorable == true) {
      chipColor = Colors.blue.shade100;
      chipText = 'Producto';
    } else if (widget.product.type == 'consu' && widget.product.isStorable == false) {
      chipColor = Colors.orange.shade100;
      chipText = 'Consumible';
    } else {
      // Fallback para otros casos (incluye type='product' sin is_storable)
      chipColor = Colors.grey.shade200;
      chipText = widget.product.type;
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

