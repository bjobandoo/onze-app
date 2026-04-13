// Providers de Riverpod para el feature de canchas.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/onze_exception.dart';
import '../../../../core/utils/logger.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../data/fields_repository_impl.dart';
import '../../domain/fields_repository.dart';
import '../../domain/models/field.dart';
import '../../domain/models/field_enums.dart';
import '../../domain/models/field_schedule.dart';
import '../../domain/models/owner_profile.dart';

final fieldsRepositoryProvider = Provider<FieldsRepository>(
  (ref) => FieldsRepositoryImpl(),
);

/// Perfil de dueño del usuario autenticado.
final myOwnerProfileProvider = FutureProvider<OwnerProfile?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;
  return ref.read(fieldsRepositoryProvider).getOwnerProfile(user.id);
});

/// Canchas verificadas y activas (mapa público).
final verifiedFieldsProvider = FutureProvider<List<Field>>((ref) async {
  return ref.read(fieldsRepositoryProvider).getVerifiedFields();
});

/// Canchas del dueño autenticado.
final myFieldsProvider = FutureProvider<List<Field>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return <Field>[];
  return ref.read(fieldsRepositoryProvider).getMyFields(user.id);
});

// ---------------------------------------------------------------------------
// BecomeOwnerNotifier
// ---------------------------------------------------------------------------

/// Estado del proceso de registro como dueño.
class BecomeOwnerState {
  const BecomeOwnerState({
    this.isLoading = false,
    this.errorMessage,
    this.profile,
  });

  final bool isLoading;
  final String? errorMessage;
  final OwnerProfile? profile;

  bool get hasError => errorMessage != null;
  bool get success => profile != null;
}

/// Notifier para el formulario de registro de dueño.
class BecomeOwnerNotifier extends StateNotifier<BecomeOwnerState> {
  BecomeOwnerNotifier(this._repo, this._userId)
      : super(const BecomeOwnerState());

  final FieldsRepository _repo;
  final String _userId;

  Future<void> register({
    required String businessName,
    required String idDocument,
  }) async {
    state = const BecomeOwnerState(isLoading: true);
    try {
      final profile = await _repo.createOwnerProfile(
        userId: _userId,
        businessName: businessName,
        idDocument: idDocument,
      );
      state = BecomeOwnerState(profile: profile);
      log.i('Usuario $_userId registrado como dueño');
    } on OnzeException catch (e) {
      state = BecomeOwnerState(errorMessage: e.message);
    } catch (e, st) {
      log.e('Error inesperado al registrarse como dueño', error: e, stackTrace: st);
      state = const BecomeOwnerState(
        errorMessage: 'Error inesperado. Intenta nuevamente.',
      );
    }
  }
}

final becomeOwnerProvider =
    StateNotifierProvider.autoDispose<BecomeOwnerNotifier, BecomeOwnerState>(
  (ref) {
    final userId = ref.watch(currentUserProvider).valueOrNull?.id ?? '';
    return BecomeOwnerNotifier(ref.read(fieldsRepositoryProvider), userId);
  },
);

// ---------------------------------------------------------------------------
// RegisterFieldNotifier
// ---------------------------------------------------------------------------

/// Estado del proceso de registro de una cancha.
class RegisterFieldState {
  const RegisterFieldState({
    this.isLoading = false,
    this.errorMessage,
    this.field,
    this.photoUploadErrors = 0,
  });

  final bool isLoading;
  final String? errorMessage;
  final Field? field;

  /// Cantidad de fotos que fallaron al subir (no bloquea el éxito).
  final int photoUploadErrors;

  bool get hasError => errorMessage != null;
  bool get success => field != null;
}

/// Notifier para el formulario de registro de cancha.
class RegisterFieldNotifier extends StateNotifier<RegisterFieldState> {
  RegisterFieldNotifier(this._repo, this._ownerId)
      : super(const RegisterFieldState());

  final FieldsRepository _repo;
  final String _ownerId;

  Future<void> register({
    required String name,
    String? description,
    required String address,
    required double latitude,
    required double longitude,
    required FieldType fieldType,
    required List<List<int>> photoBytes,
  }) async {
    state = const RegisterFieldState(isLoading: true);
    try {
      // 1. Crear la cancha
      final field = await _repo.registerField(
        ownerId: _ownerId,
        name: name,
        description: description,
        address: address,
        latitude: latitude,
        longitude: longitude,
        fieldType: fieldType,
      );

      // 2. Subir fotos (fallos no bloquean)
      int photoErrors = 0;
      final photoUrls = <String>[];
      for (int i = 0; i < photoBytes.length; i++) {
        try {
          final url = await _repo.uploadFieldPhoto(
            fieldId: field.id,
            photoIndex: i,
            bytes: Uint8List.fromList(photoBytes[i]),
          );
          photoUrls.add(url);
        } catch (_) {
          photoErrors++;
        }
      }

      // 3. Actualizar fotos si las hubo
      if (photoUrls.isNotEmpty) {
        await _repo.updateFieldPhotos(
          fieldId: field.id,
          photoUrls: photoUrls,
        );
      }

      state = RegisterFieldState(field: field, photoUploadErrors: photoErrors);
      log.i('Cancha registrada: ${field.id}');
    } on OnzeException catch (e) {
      state = RegisterFieldState(errorMessage: e.message);
    } catch (e, st) {
      log.e('Error inesperado al registrar cancha', error: e, stackTrace: st);
      state = const RegisterFieldState(
        errorMessage: 'Error inesperado. Intenta nuevamente.',
      );
    }
  }
}

final registerFieldProvider = StateNotifierProvider.autoDispose<
    RegisterFieldNotifier, RegisterFieldState>(
  (ref) {
    final ownerId = ref.watch(currentUserProvider).valueOrNull?.id ?? '';
    return RegisterFieldNotifier(ref.read(fieldsRepositoryProvider), ownerId);
  },
);

// ---------------------------------------------------------------------------
// EditFieldNotifier
// ---------------------------------------------------------------------------

/// Estado del proceso de edición de una cancha.
class EditFieldState {
  const EditFieldState({
    this.isLoading = false,
    this.errorMessage,
    this.field,
    this.photoUploadErrors = 0,
  });

  final bool isLoading;
  final String? errorMessage;
  final Field? field;

  /// Cantidad de fotos nuevas que fallaron al subir (no bloquea el éxito).
  final int photoUploadErrors;

  bool get hasError => errorMessage != null;
  bool get success => field != null;
}

/// Notifier para el formulario de edición de cancha.
class EditFieldNotifier extends StateNotifier<EditFieldState> {
  EditFieldNotifier(this._repo) : super(const EditFieldState());

  final FieldsRepository _repo;

  Future<void> update({
    required String fieldId,
    required String name,
    String? description,
    required String address,
    required double latitude,
    required double longitude,
    required FieldType fieldType,
    required List<String> keptPhotoUrls,
    required List<List<int>> newPhotoBytes,
  }) async {
    state = const EditFieldState(isLoading: true);
    try {
      // 1. Actualizar datos básicos
      final field = await _repo.updateField(
        fieldId: fieldId,
        name: name,
        description: description,
        address: address,
        latitude: latitude,
        longitude: longitude,
        fieldType: fieldType,
      );

      // 2. Subir fotos nuevas (los índices parten desde el número de fotos
      //    existentes que se conservan para evitar sobreescribir)
      int photoErrors = 0;
      final finalUrls = [...keptPhotoUrls];
      for (int i = 0; i < newPhotoBytes.length; i++) {
        try {
          final url = await _repo.uploadFieldPhoto(
            fieldId: fieldId,
            photoIndex: keptPhotoUrls.length + i,
            bytes: Uint8List.fromList(newPhotoBytes[i]),
          );
          finalUrls.add(url);
        } catch (_) {
          photoErrors++;
        }
      }

      // 3. Persistir el array final de fotos
      await _repo.updateFieldPhotos(
        fieldId: fieldId,
        photoUrls: finalUrls,
      );

      state = EditFieldState(field: field, photoUploadErrors: photoErrors);
      log.i('Cancha $fieldId actualizada (fotos: ${finalUrls.length})');
    } on OnzeException catch (e) {
      state = EditFieldState(errorMessage: e.message);
    } catch (e, st) {
      log.e('Error inesperado al actualizar cancha', error: e, stackTrace: st);
      state = const EditFieldState(
        errorMessage: 'Error inesperado. Intenta nuevamente.',
      );
    }
  }
}

final editFieldProvider =
    StateNotifierProvider.autoDispose<EditFieldNotifier, EditFieldState>(
  (ref) => EditFieldNotifier(ref.read(fieldsRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Horarios
// ---------------------------------------------------------------------------

/// Bloques horarios de una cancha específica.
final fieldSchedulesProvider =
    FutureProvider.family<List<FieldSchedule>, String>((ref, fieldId) async {
  return ref.read(fieldsRepositoryProvider).getFieldSchedules(fieldId);
});

/// Estado del editor de horarios.
class ManageSchedulesState {
  const ManageSchedulesState({
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
}

/// Notifier para crear, editar, eliminar y alternar bloques horarios.
class ManageSchedulesNotifier
    extends StateNotifier<ManageSchedulesState> {
  ManageSchedulesNotifier(this._repo, this._fieldId)
      : super(const ManageSchedulesState());

  final FieldsRepository _repo;
  final String _fieldId;

  Future<bool> upsert({
    String? id,
    required int dayOfWeek,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double price,
    bool isActive = true,
  }) async {
    state = const ManageSchedulesState(isLoading: true);
    try {
      await _repo.upsertSchedule(
        id: id,
        fieldId: _fieldId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        price: price,
        isActive: isActive,
      );
      state = const ManageSchedulesState();
      return true;
    } on OnzeException catch (e) {
      state = ManageSchedulesState(errorMessage: e.message);
      return false;
    } catch (e, st) {
      log.e('Error inesperado al guardar horario', error: e, stackTrace: st);
      state = const ManageSchedulesState(
        errorMessage: 'Error inesperado. Intenta nuevamente.',
      );
      return false;
    }
  }

  Future<bool> delete(String id) async {
    state = const ManageSchedulesState(isLoading: true);
    try {
      await _repo.deleteSchedule(id);
      state = const ManageSchedulesState();
      return true;
    } on OnzeException catch (e) {
      state = ManageSchedulesState(errorMessage: e.message);
      return false;
    } catch (e, st) {
      log.e('Error inesperado al eliminar horario', error: e, stackTrace: st);
      state = const ManageSchedulesState(
        errorMessage: 'Error inesperado. Intenta nuevamente.',
      );
      return false;
    }
  }

  /// Crea un horario para cada día en [dayOfWeeks] con el mismo rango y precio.
  /// Devuelve la cantidad de bloques creados exitosamente.
  Future<int> bulkUpsert({
    required Set<int> dayOfWeeks,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double price,
  }) async {
    state = const ManageSchedulesState(isLoading: true);
    int created = 0;
    try {
      for (final day in dayOfWeeks) {
        await _repo.upsertSchedule(
          fieldId: _fieldId,
          dayOfWeek: day,
          startTime: startTime,
          endTime: endTime,
          price: price,
        );
        created++;
      }
      state = const ManageSchedulesState();
    } on OnzeException catch (e) {
      state = ManageSchedulesState(errorMessage: e.message);
    } catch (e, st) {
      log.e('Error en creación masiva de horarios', error: e, stackTrace: st);
      state = const ManageSchedulesState(
        errorMessage: 'Error inesperado. Intenta nuevamente.',
      );
    }
    return created;
  }

  Future<void> toggleActive(String id, {required bool isActive}) async {
    try {
      await _repo.setScheduleActive(id, isActive: isActive);
    } on OnzeException catch (e) {
      state = ManageSchedulesState(errorMessage: e.message);
    } catch (e, st) {
      log.e('Error inesperado al cambiar estado del horario',
          error: e, stackTrace: st);
    }
  }
}

final manageSchedulesProvider = StateNotifierProvider.autoDispose
    .family<ManageSchedulesNotifier, ManageSchedulesState, String>(
  (ref, fieldId) =>
      ManageSchedulesNotifier(ref.read(fieldsRepositoryProvider), fieldId),
);
