import 'package:isar/isar.dart';

part 'offline_models.g.dart';

@collection
class OfflineMutation {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String mutationId; // UUID to avoid duplicates
  
  late String collectionName; // e.g. 'purchases', 'farmers', 'cash_movements'
  
  late String action; // 'insert', 'update', 'delete'
  
  late String payload; // JSON string representation of the data
  
  late DateTime createdAt;
}

@collection
class LocalFarmer {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String supabaseId; // UUID from Supabase
  
  @Index()
  late String businessId;
  
  @Index()
  String? folderId;
  
  late String name;
  String? whatsappNumber;
  String? lastName;
  String? email;
  String? description;
}

@collection
class LocalBusinessConfig {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String businessId; // UUID from Supabase
  
  late String data; // JSON string of the business configuration
}

@collection
class LocalFolder {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String supabaseId;

  @Index()
  late String businessId;

  @Index()
  String? parentId;
  
  late String name;
  late String contentType; // 'none', 'documents', 'contacts'
}

@collection
class LocalDocument {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String supabaseId;

  @Index()
  late String businessId;

  @Index()
  late String folderId;

  late String name;
  late String fileUrl;
  String? fileType;
  int? sizeBytes;
}
