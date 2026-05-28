import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/business_provider.dart';
import '../../../shared/models/folder_model.dart';
import '../../../shared/models/document_model.dart';
import '../../../shared/models/farmer_model.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Navegación
  String? _currentFolderId;
  List<FolderModel> _breadcrumbs = [];
  FolderModel? _currentFolder;

  // Datos
  List<FolderModel> _subFolders = [];
  List<DocumentModel> _documents = [];
  List<FarmerModel> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final businessId = context.read<BusinessProvider>().business?.id;
      if (businessId == null) return;

      // 1. Cargar subcarpetas
      var folderQuery = _supabase.from('folders').select().eq('business_id', businessId);
      if (_currentFolderId == null) {
        folderQuery = folderQuery.isFilter('parent_id', null);
      } else {
        folderQuery = folderQuery.eq('parent_id', _currentFolderId as Object);
      }
      final folderData = await folderQuery.order('name');
      _subFolders = (folderData as List).map((e) => FolderModel.fromMap(e)).toList();

      if (_currentFolderId == null) {
        // Auto-crear "Directorio de Clientes" si no existe
        final directoryExists = _subFolders.any((f) => f.name == 'Directorio de Clientes');
        String directoryId;

        if (!directoryExists) {
          directoryId = const Uuid().v4();
          await _supabase.from('folders').insert({
            'id': directoryId,
            'business_id': businessId,
            'parent_id': null,
            'name': 'Directorio de Clientes',
            'content_type': 'contacts',
          });
          // Recargar carpetas para mostrarla
          final newFolderData = await folderQuery.order('name');
          _subFolders = (newFolderData as List).map((e) => FolderModel.fromMap(e)).toList();
        } else {
          directoryId = _subFolders.firstWhere((f) => f.name == 'Directorio de Clientes').id;
        }

        // Asignar los contactos "huérfanos" a esta carpeta (los que aún no tienen folder_id)
        await _supabase
            .from('farmers')
            .update({'folder_id': directoryId})
            .eq('business_id', businessId)
            .isFilter('folder_id', null);
      }

      // 2. Cargar contenido (solo si estamos dentro de una carpeta)
      _documents = [];
      _contacts = [];
      if (_currentFolderId != null) {
        final docData = await _supabase
            .from('documents')
            .select()
            .eq('business_id', businessId)
            .eq('folder_id', _currentFolderId as Object)
            .order('name');
        _documents = (docData as List).map((e) => DocumentModel.fromMap(e)).toList();

        final contactData = await _supabase
            .from('farmers')
            .select()
            .eq('business_id', businessId)
            .eq('folder_id', _currentFolderId as Object)
            .order('name');
        _contacts = (contactData as List).map((e) => FarmerModel.fromMap(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToFolder(FolderModel folder) {
    setState(() {
      _currentFolderId = folder.id;
      _currentFolder = folder;
      _breadcrumbs.add(folder);
    });
    _loadData();
  }

  void _navigateUpTo(int index) {
    setState(() {
      _breadcrumbs = _breadcrumbs.sublist(0, index + 1);
      _currentFolder = _breadcrumbs.last;
      _currentFolderId = _currentFolder?.id;
    });
    _loadData();
  }

  void _navigateToRoot() {
    setState(() {
      _currentFolderId = null;
      _currentFolder = null;
      _breadcrumbs.clear();
    });
    _loadData();
  }

  // --- ACCIONES ---

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Carpeta'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre de la carpeta'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final businessId = context.read<BusinessProvider>().business?.id;
      final newId = const Uuid().v4();
      await _supabase.from('folders').insert({
        'id': newId,
        'business_id': businessId,
        'parent_id': _currentFolderId,
        'name': name,
        'content_type': 'none',
      });
      _loadData();
    }
  }

  Future<void> _addContact() async {
    final nameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Persona'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre *')),
              TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Apellido (opcional)')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono (opcional)'), keyboardType: TextInputType.phone),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Correo (opcional)'), keyboardType: TextInputType.emailAddress),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción (opcional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == true && nameCtrl.text.isNotEmpty) {
      final businessId = context.read<BusinessProvider>().business?.id;
      final newId = const Uuid().v4();
      await _supabase.from('farmers').insert({
        'id': newId,
        'business_id': businessId,
        'folder_id': _currentFolderId,
        'name': nameCtrl.text.trim(),
        'last_name': lastNameCtrl.text.trim().isEmpty ? null : lastNameCtrl.text.trim(),
        'whatsapp_number': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
        'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      });
      // Actualizar content_type de la carpeta a contacts si estaba none
      if (_currentFolder?.contentType == 'none') {
        await _supabase.from('folders').update({'content_type': 'contacts'}).eq('id', _currentFolderId as Object);
        _currentFolder = FolderModel(
          id: _currentFolder!.id, businessId: _currentFolder!.businessId, parentId: _currentFolder!.parentId, 
          name: _currentFolder!.name, contentType: 'contacts', createdAt: _currentFolder!.createdAt
        );
      }
      _loadData();
    }
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final fileName = result.files.single.name;
    final fileExt = result.files.single.extension;
    final size = result.files.single.size;
    final businessId = context.read<BusinessProvider>().business?.id;

    setState(() => _isLoading = true);
    try {
      final storagePath = '$businessId/$_currentFolderId/${const Uuid().v4()}.$fileExt';
      await _supabase.storage.from('business_documents').upload(storagePath, file);
      final fileUrl = _supabase.storage.from('business_documents').getPublicUrl(storagePath);

      final newId = const Uuid().v4();
      await _supabase.from('documents').insert({
        'id': newId,
        'business_id': businessId,
        'folder_id': _currentFolderId,
        'name': fileName,
        'file_url': fileUrl,
        'file_type': fileExt,
        'size_bytes': size,
      });

      // Actualizar content_type
      if (_currentFolder?.contentType == 'none') {
        await _supabase.from('folders').update({'content_type': 'documents'}).eq('id', _currentFolderId as Object);
        _currentFolder = FolderModel(
          id: _currentFolder!.id, businessId: _currentFolder!.businessId, parentId: _currentFolder!.parentId, 
          name: _currentFolder!.name, contentType: 'documents', createdAt: _currentFolder!.createdAt
        );
      }
    } catch (e) {
      debugPrint('Error uploading: $e');
    } finally {
      _loadData();
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestor de Archivos'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildBreadcrumbs(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_subFolders.isNotEmpty) ...[
                          const Text('Carpetas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _subFolders.length,
                            itemBuilder: (ctx, i) {
                              final f = _subFolders[i];
                              return GestureDetector(
                                onTap: () => _navigateToFolder(f),
                                child: Column(
                                  children: [
                                    const Icon(Icons.folder, size: 60, color: Colors.amber),
                                    Text(f.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (_contacts.isNotEmpty) ...[
                          const Text('Personas / Contactos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ..._contacts.map((c) => ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(c.name),
                            subtitle: Text(c.whatsappNumber ?? c.description ?? 'Sin detalles'),
                            onTap: () {
                              context.push('/contact_profile', extra: {'farmerId': c.id});
                            },
                          )),
                        ],
                        if (_documents.isNotEmpty) ...[
                          const Text('Documentos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ..._documents.map((d) => ListTile(
                            leading: const Icon(Icons.insert_drive_file, color: Colors.blue, size: 40),
                            title: Text(d.name),
                            subtitle: Text(d.fileType?.toUpperCase() ?? 'Archivo'),
                            trailing: IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () {
                                // Aquí se podría abrir el archivo en el navegador web
                                debugPrint('Descargar: ${d.fileUrl}');
                              },
                            ),
                          )),
                        ],
                        if (_subFolders.isEmpty && _contacts.isEmpty && _documents.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text('La carpeta está vacía', style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildBreadcrumbs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            GestureDetector(
              onTap: _navigateToRoot,
              child: const Row(
                children: [
                  Icon(Icons.home, size: 20, color: Color(0xFF1B5E20)),
                  SizedBox(width: 4),
                  Text('Inicio', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                ],
              ),
            ),
            ..._breadcrumbs.asMap().entries.map((e) {
              return Row(
                children: [
                  const Icon(Icons.chevron_right, color: Colors.grey),
                  GestureDetector(
                    onTap: () => _navigateUpTo(e.key),
                    child: Text(
                      e.value.name,
                      style: TextStyle(
                        fontWeight: e.key == _breadcrumbs.length - 1 ? FontWeight.bold : FontWeight.normal,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget? _buildFAB() {
    if (_currentFolderId == null) {
      // En la raíz solo podemos crear carpetas
      return FloatingActionButton.extended(
        onPressed: _createFolder,
        icon: const Icon(Icons.create_new_folder),
        label: const Text('Nueva Carpeta'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      );
    }

    final cType = _currentFolder?.contentType ?? 'none';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (cType == 'none' || cType == 'documents')
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.extended(
              heroTag: 'doc',
              onPressed: _uploadDocument,
              icon: const Icon(Icons.upload_file),
              label: const Text('Subir Documento'),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        if (cType == 'none' || cType == 'contacts')
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.extended(
              heroTag: 'person',
              onPressed: _addContact,
              icon: const Icon(Icons.person_add),
              label: const Text('Agregar Persona'),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        FloatingActionButton.extended(
          heroTag: 'folder',
          onPressed: _createFolder,
          icon: const Icon(Icons.create_new_folder),
          label: const Text('Nueva Carpeta'),
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}
