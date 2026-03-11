import 'package:flutter_dotenv/flutter_dotenv.dart';

// ============================================================
// AccessPolicy — Single source of truth untuk izin berbasis peran.
// Ketua   : Create, Read, Update, Delete seluruh log tim.
// Reviewer: Read, Update seluruh log tim.
// Anggota : Read only.
// ============================================================
class AccessPolicy {
  static const String roleKetua = 'Ketua';
  static const String roleReviewer = 'Reviewer';
  static const String roleAnggota = 'Anggota';
  // Backward-compat alias
  static const String roleAsisten = roleReviewer;

  static const String actionCreate = 'create';
  static const String actionRead = 'read';
  static const String actionUpdate = 'update';
  static const String actionDelete = 'delete';

  /// Daftar peran yang valid (dapat di-override via APP_ROLES di .env).
  static List<String> get availableRoles =>
      dotenv.env['APP_ROLES']?.split(',') ??
      [roleAnggota, roleReviewer, roleKetua];

  /// Matriks dasar disisakan untuk kompatibilitas, tetapi update/delete
  /// tidak lagi ditentukan oleh role.
  static final Map<String, Set<String>> _matrix = {
    roleKetua: {actionCreate, actionRead, actionUpdate, actionDelete},
    roleReviewer: {actionCreate, actionRead, actionUpdate, actionDelete},
    roleAnggota: {actionCreate, actionRead, actionUpdate, actionDelete},
  };

  /// Cek apakah [role] boleh melakukan [action].
  /// [isOwner] disediakan untuk kompatibilitas, namun pada policy ini
  /// akses murni ditentukan berdasarkan role.
  static bool canPerform(String role, String action, {bool isOwner = false}) {
    if (action == actionUpdate || action == actionDelete) {
      return isOwner;
    }
    return _matrix[role]?.contains(action) ?? true;
  }

  /// Validasi apakah resource berada dalam tim yang sama.
  static bool isSameTeam(String? userTeamId, String? resourceTeamId) {
    if (userTeamId == null || resourceTeamId == null) return false;
    return userTeamId.trim().isNotEmpty && userTeamId == resourceTeamId;
  }

  /// Gabungan cek role + team boundary.
  static bool canAccessByTeam(
    String role,
    String action, {
    required String? userTeamId,
    required String? resourceTeamId,
  }) {
    return isSameTeam(userTeamId, resourceTeamId) && canPerform(role, action);
  }

  /// Visibility rule:
  /// - Owner selalu bisa lihat.
  /// - Non-owner hanya bisa lihat jika log bersifat public dan satu tim.
  static bool canViewLog({
    required String? currentUserId,
    required String? logAuthorId,
    required bool isPublic,
    required String? currentUserTeamId,
    required String? logTeamId,
  }) {
    final isOwner = currentUserId != null && currentUserId == logAuthorId;
    if (isOwner) return true;
    return isPublic && isSameTeam(currentUserTeamId, logTeamId);
  }

  /// Sovereignty rule: hanya pemilik catatan yang boleh edit/hapus.
  static bool canModifyLog({
    required String? currentUserId,
    required String? logAuthorId,
  }) {
    return currentUserId != null && currentUserId == logAuthorId;
  }

  /// Kembalikan label peran yang mudah dibaca.
  static String labelFor(String role) {
    switch (role) {
      case roleKetua:
        return 'Ketua';
      case roleReviewer:
        return 'Reviewer';
      case roleAnggota:
        return 'Anggota';
      default:
        return role;
    }
  }
}

// ============================================================
// AccessControlService — Wrapper backward-compat.
// Semua kode lama yang import AccessControlService tetap bekerja.
// ============================================================
class AccessControlService {
  static List<String> get availableRoles => AccessPolicy.availableRoles;

  static const String actionCreate = AccessPolicy.actionCreate;
  static const String actionRead = AccessPolicy.actionRead;
  static const String actionUpdate = AccessPolicy.actionUpdate;
  static const String actionDelete = AccessPolicy.actionDelete;

  static bool canPerform(String role, String action, {bool isOwner = false}) =>
      AccessPolicy.canPerform(role, action, isOwner: isOwner);
}
