import 'package:flutter/foundation.dart';

/// Represents an authenticated user in the QuickNews application.
@immutable
class UserEntity {
  /// Unique identifier of the user.
  final String id;

  /// User's email address.
  final String email;

  /// User's display name.
  final String displayName;

  /// Mock authentication token indicating an active session.
  final String? token;

  const UserEntity({
    required this.id,
    required this.email,
    required this.displayName,
    this.token,
  });

  /// Factory constructor to create a [UserEntity] from a JSON map.
  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      token: json['token'] as String?,
    );
  }

  /// Converts this [UserEntity] into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      if (token != null) 'token': token,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          displayName == other.displayName &&
          token == other.token;

  @override
  int get hashCode => Object.hash(id, email, displayName, token);

  @override
  String toString() =>
      'UserEntity(id: $id, email: $email, displayName: $displayName)';
}
