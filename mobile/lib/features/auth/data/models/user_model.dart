import 'package:equatable/equatable.dart';

import 'store_model.dart';

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.store,
  });

  /// UUID pengguna (sama dengan auth.users.id di Supabase).
  final String id;
  final String name;
  final String email;

  /// "OWNER" atau "ADMIN" (lihat tabel profiles pada supabase/schema.sql).
  final String role;
  final StoreModel? store;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'].toString(),
        name: json['name'] as String,
        email: json['email'] as String,
        role: (json['role'] as String?) ?? 'OWNER',
        store: json['store'] is Map<String, dynamic>
            ? StoreModel.fromJson(json['store'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'store': store?.toJson(),
      };

  @override
  List<Object?> get props => [id, name, email, role, store];
}
