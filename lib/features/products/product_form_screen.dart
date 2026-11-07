import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/labels.dart';
import '../../models/product.dart';
import '../scanner/barcode_lookup_service.dart';
import '../scanner/barcode_scanner_screen.dart';
import 'product_provider.dart';
import 'widgets/product_widgets.dart';

const _statuses = ['ACTIVE', 'INACTIVE'];

class ProductFormScreen extends StatefulWidget {
  final String businessId;
  final Product? product;

  /// Código de barras ya escaneado (ej. desde la lista de productos) para un producto nuevo.
  final String? initialSku;

  const ProductFormScreen({super.key, required this.businessId, this.product, this.initialSku});

  bool get isEditing => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.product?.name);
  late final _categoryController = TextEditingController(text: widget.product?.category);
  late final _unitController = TextEditingController(text: widget.product?.unit);
  late final _skuController = TextEditingController(text: widget.product?.sku ?? widget.initialSku);
  late final _priceController = TextEditingController(text: widget.product?.price.toStringAsFixed(2));
  late final _costController = TextEditingController(text: widget.product?.cost?.toStringAsFixed(2));
  late final _stockController = TextEditingController(text: widget.product == null ? '0' : null);
  late final _lowStockController = TextEditingController(text: (widget.product?.lowStockThreshold ?? 5).toString());
  late String _status = widget.product?.status ?? _statuses.first;
  bool _isSubmitting = false;
  bool _isLookingUp = false;
  String? _errorMessage;

  /// Imagen ya publicada (la del producto o la encontrada en internet por el código de barras).
  late String? _imageUrl = widget.product?.imageUrl;

  /// Foto tomada o elegida de la galería, pendiente de subir al guardar.
  Uint8List? _pickedImage;
  String _pickedImageType = 'image/jpeg';
  bool _imageMissing = false;
  bool _submitAttempted = false;

  /// Valores puestos por el último escaneo; si el usuario no los cambió, otro escaneo los reemplaza.
  String? _autoName;
  String? _autoCategory;
  String? _autoImageUrl;

  bool get _hasImage => _pickedImage != null || (_imageUrl?.isNotEmpty ?? false);

  /// Vacío o todavía con el dato del escaneo anterior (no lo escribió el usuario).
  bool _isReplaceable(TextEditingController controller, String? autoValue) {
    final text = controller.text.trim();
    return text.isEmpty || (autoValue != null && text == autoValue);
  }

  bool get _imageReplaceable => !_hasImage || (_pickedImage == null && _imageUrl == _autoImageUrl);

  @override
  void initState() {
    super.initState();
    if (widget.initialSku != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fillFromBarcode(widget.initialSku!));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      setState(() {
        _pickedImage = bytes;
        _pickedImageType = name.endsWith('.png')
            ? 'image/png'
            : name.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
        _imageMissing = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(source == ImageSource.camera ? 'No se pudo abrir la cámara.' : 'No se pudo abrir la galería.'),
        ),
      );
    }
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            if (_skuController.text.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.travel_explore_rounded),
                title: const Text('Buscar por código de barras'),
                subtitle: const Text('Usa la imagen publicada del empaque'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _fillFromBarcode(_skuController.text.trim(), forceImage: true);
                },
              ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    _skuController.text = code;
    await _fillFromBarcode(code);
  }

  /// Autocompleta nombre, categoría e imagen con los datos públicos del empaque, sin pisar lo que
  /// escribió el usuario (lo que llenó un escaneo anterior sí se reemplaza).
  /// Con [forceImage] reemplaza la imagen actual por la encontrada en internet.
  Future<void> _fillFromBarcode(String code, {bool forceImage = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final duplicate = context.read<ProductProvider>().findByBarcode(code);
    if (duplicate != null && duplicate.id != widget.product?.id) {
      messenger.showSnackBar(SnackBar(content: Text('Este código ya está asignado a "${duplicate.name}".')));
      return;
    }
    if (!forceImage &&
        !_imageReplaceable &&
        !_isReplaceable(_nameController, _autoName) &&
        !_isReplaceable(_categoryController, _autoCategory)) {
      return;
    }

    setState(() => _isLookingUp = true);
    final info = await BarcodeLookupService().lookup(code);
    if (!mounted) return;
    setState(() => _isLookingUp = false);

    if (info == null) {
      // Los datos del escaneo anterior ya no corresponden a este código.
      setState(() {
        if (_autoName != null && _isReplaceable(_nameController, _autoName)) _nameController.clear();
        if (_autoCategory != null && _isReplaceable(_categoryController, _autoCategory)) _categoryController.clear();
        if (_autoImageUrl != null && _imageReplaceable) _imageUrl = null;
        _autoName = _autoCategory = _autoImageUrl = null;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('No encontramos este producto en internet. Completa los datos y toma una foto.')),
      );
      return;
    }
    final category = info.category != null && info.category!.length <= 80 ? info.category : null;
    setState(() {
      if (forceImage || _imageReplaceable) {
        if (info.imageUrl != null) {
          _imageUrl = info.imageUrl;
          _pickedImage = null;
          _imageMissing = false;
        } else if (_autoImageUrl != null && _imageUrl == _autoImageUrl) {
          _imageUrl = null;
        }
        _autoImageUrl = info.imageUrl;
      }
      if (_isReplaceable(_nameController, _autoName)) {
        _nameController.text = info.suggestedName;
        _autoName = info.suggestedName;
      }
      if (_isReplaceable(_categoryController, _autoCategory)) {
        _categoryController.text = category ?? '';
        _autoCategory = category;
      }
    });
    // Si ya se intentó guardar, revalida para quitar los "Requerido" de los campos que se llenaron solos.
    if (_submitAttempted) _formKey.currentState?.validate();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          info.imageUrl == null
              ? 'Datos completados, pero el producto no tiene imagen publicada. Toma una foto.'
              : 'Datos e imagen del producto completados. Revisa y agrega el precio.',
        ),
      ),
    );
  }

  Future<void> _submit() async {
    _submitAttempted = true;
    final formValid = _formKey.currentState!.validate();
    setState(() => _imageMissing = !_hasImage);
    if (!formValid || !_hasImage) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final provider = context.read<ProductProvider>();
      if (_pickedImage != null) {
        _imageUrl = await provider.uploadImage(widget.businessId, _pickedImage!, contentType: _pickedImageType);
        _pickedImage = null;
      }
      final price = double.parse(_priceController.text.replaceAll(',', '.'));
      final cost = _costController.text.trim().isEmpty ? null : double.parse(_costController.text.replaceAll(',', '.'));
      final lowStockThreshold = int.tryParse(_lowStockController.text) ?? 5;

      if (widget.isEditing) {
        await provider.updateProduct(
          widget.businessId,
          widget.product!.id,
          name: _nameController.text.trim(),
          price: price,
          cost: cost,
          lowStockThreshold: lowStockThreshold,
          category: _categoryController.text.trim(),
          unit: _unitController.text.trim(),
          sku: _skuController.text.trim(),
          imageUrl: _imageUrl,
          status: _status,
        );
      } else {
        await provider.createProduct(
          widget.businessId,
          name: _nameController.text.trim(),
          price: price,
          cost: cost,
          stock: int.tryParse(_stockController.text) ?? 0,
          lowStockThreshold: lowStockThreshold,
          category: _categoryController.text.trim(),
          unit: _unitController.text.trim(),
          sku: _skuController.text.trim(),
          imageUrl: _imageUrl,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Editar producto' : 'Nuevo producto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ImagePickerBox(
                pickedImage: _pickedImage,
                imageUrl: _imageUrl,
                missing: _imageMissing,
                loading: _isLookingUp,
                onTap: _isSubmitting ? null : _chooseImageSource,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _skuController,
                maxLength: 60,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (code) {
                  if (code.trim().isNotEmpty) _fillFromBarcode(code.trim());
                },
                decoration: InputDecoration(
                  labelText: 'Código de barras (opcional)',
                  counterText: '',
                  suffixIcon: _isLookingUp
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          tooltip: 'Escanear código de barras',
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scan,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre del producto'),
                validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Categoría (opcional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Unidad (ej. unidad, kg)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Precio de venta'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerido';
                        if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Número inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Costo (opcional)'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Número inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!widget.isEditing) ...[
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stock inicial'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: TextFormField(
                      controller: _lowStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Alertar si el stock baja de'),
                    ),
                  ),
                ],
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(Labels.status(s)))).toList(),
                  onChanged: (value) => setState(() => _status = value ?? _statuses.first),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.isEditing ? 'Guardar cambios' : 'Guardar producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recuadro de la foto del producto (obligatoria): muestra la foto elegida, la encontrada en internet
/// o una invitación a agregarla.
class _ImagePickerBox extends StatelessWidget {
  final Uint8List? pickedImage;
  final String? imageUrl;
  final bool missing;
  final bool loading;
  final VoidCallback? onTap;

  const _ImagePickerBox({
    required this.pickedImage,
    required this.imageUrl,
    required this.missing,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final hasImage = pickedImage != null || (imageUrl?.isNotEmpty ?? false);
    final accent = missing ? errorColor : AppTheme.primary;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: missing ? errorColor : AppTheme.border, width: missing ? 1.5 : 1),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: pickedImage != null
                            ? Image.memory(pickedImage!, fit: BoxFit.cover, width: 150, height: 150)
                            : ProductImage(url: imageUrl, size: 150, radius: 0),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 40, color: accent),
                          const SizedBox(height: 8),
                          Text(
                            'Agregar foto',
                            style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
              if (loading) const CircularProgressIndicator(),
              if (hasImage && !loading)
                const Positioned(
                  right: 6,
                  bottom: 6,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primary,
                    child: Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          missing
              ? 'La foto del producto es obligatoria'
              : 'Escanea el código de barras para traer la foto de internet, o toma una.',
          textAlign: TextAlign.center,
          style: TextStyle(color: missing ? errorColor : AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
