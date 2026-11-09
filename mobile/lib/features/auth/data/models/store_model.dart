import 'package:equatable/equatable.dart';

class StoreModel extends Equatable {
  const StoreModel({
    required this.id,
    required this.storeName,
    this.address,
    this.phone,
  });

  final int id;
  final String storeName;
  final String? address;
  final String? phone;

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id: (json['id'] as num).toInt(),
        storeName: json['store_name'] as String,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_name': storeName,
        'address': address,
        'phone': phone,
      };

  @override
  List<Object?> get props => [id, storeName, address, phone];
}
