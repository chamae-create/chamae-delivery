import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final int stock;
  final bool isActive;
  final String imageUrl;
  final String description;
  final bool isOffer;
  final bool isCombo;
  final int salesCount;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.isActive,
    required this.imageUrl,
    required this.description,
    required this.isOffer,
    required this.isCombo,
    required this.salesCount,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Product(
      id: doc.id,
      name: (data['name'] ?? 'Produto').toString(),
      category: (data['category'] ?? 'Geral').toString(),
      price:
          ((data['priceBRL'] ?? data['price'] ?? 0) as num).toDouble(),
      stock: ((data['stock'] ?? 0) as num).toInt(),
      isActive: (data['isActive'] ?? true) as bool,
      imageUrl: (data['imageUrl'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      isOffer: (data['isOffer'] ?? false) as bool,
      isCombo: (data['isCombo'] ?? false) as bool,
      salesCount: ((data['salesCount'] ?? 0) as num).toInt(),
    );
  }
}

class CartItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.quantity = 1,
  });

  double get totalPrice => price * quantity;
}

/// Endereço/localização selecionado pelo cliente.
///
/// Nesta primeira etapa armazenamos as coordenadas exatas do ponto
/// escolhido no mapa e uma descrição opcional do endereço.
///
/// Mais adiante poderemos acrescentar número, complemento,
/// referência e endereço obtido automaticamente sem quebrar
/// a estrutura dos pedidos existentes.
class DeliveryAddress {
  final double latitude;
  final double longitude;
  final String addressText;
  final String complement;
  final String reference;

  const DeliveryAddress({
    required this.latitude,
    required this.longitude,
    this.addressText = '',
    this.complement = '',
    this.reference = '',
  });

  DeliveryAddress copyWith({
    double? latitude,
    double? longitude,
    String? addressText,
    String? complement,
    String? reference,
  }) {
    return DeliveryAddress(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addressText: addressText ?? this.addressText,
      complement: complement ?? this.complement,
      reference: reference ?? this.reference,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'addressText': addressText,
      'complement': complement,
      'reference': reference,
    };
  }

  factory DeliveryAddress.fromMap(
    Map<String, dynamic> data,
  ) {
    return DeliveryAddress(
      latitude: ((data['latitude'] ?? 0) as num).toDouble(),
      longitude: ((data['longitude'] ?? 0) as num).toDouble(),
      addressText: (data['addressText'] ?? '').toString(),
      complement: (data['complement'] ?? '').toString(),
      reference: (data['reference'] ?? '').toString(),
    );
  }

  GeoPoint get geoPoint => GeoPoint(
        latitude,
        longitude,
      );

  bool get hasCoordinates =>
      latitude != 0 && longitude != 0;

  String get coordinatesText =>
      '${latitude.toStringAsFixed(6)}, '
      '${longitude.toStringAsFixed(6)}';
}

class OrderModel {
  final String documentId;
  final String id;
  final String customerName;
  final String customerPhone;
  final String address;
  final double totalBRL;
  final String paymentMethod;
  String status;
  final String courierName;
  final bool courierPaid;
  final DateTime? createdAt;

  OrderModel({
    required this.documentId,
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.totalBRL,
    required this.paymentMethod,
    required this.status,
    required this.courierName,
    required this.courierPaid,
    required this.createdAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = data['createdAt'];

    return OrderModel(
      documentId: doc.id,
      id: (data['id'] ?? doc.id).toString(),
      customerName:
          (data['customerName'] ?? '').toString(),
      customerPhone:
          (data['customerPhone'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      totalBRL:
          ((data['totalBRL'] ?? 0) as num).toDouble(),
      paymentMethod:
          (data['paymentMethod'] ?? '').toString(),
      status: (data['status'] ?? 'Novo').toString(),
      courierName:
          (data['courierName'] ?? '').toString(),
      courierPaid:
          (data['courierPaid'] ?? false) as bool,
      createdAt:
          timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class UserSession {
  static String fullName = '';
  static String socialName = '';
  static String whatsapp = '';
  static String document = '';
  static String language = 'pt';
  static bool isRegistered = false;
}