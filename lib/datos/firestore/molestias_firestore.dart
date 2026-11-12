/// Las molestias recientes de un nadador, leídas de sus registros.
///
/// **Solo lee, y esa es toda la idea.** La feature 008 enseña al entrenador lo
/// que el nadador ya contó en sus sesiones, y no guarda una copia en ninguna
/// parte: un dato de salud de un menor duplicado es un segundo sitio desde el
/// que puede filtrarse, un segundo sitio que borrar al ejercer la supresión, y
/// un segundo sitio que puede discrepar del primero (FR-038).
///
/// Las reglas ya permiten esta lectura: el entrenador lee los registros de su
/// comunidad desde la feature 007. No hizo falta abrir nada.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/firestore/lo_que_haya.dart';
import 'package:natacion_app/datos/firestore/envio_registros.dart';
import 'package:natacion_app/dominio/peticiones/molestias_enlazadas.dart';

class MolestiasFirestore implements LectorDeMolestias {
  const MolestiasFirestore(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<List<MolestiaEnlazada>> recientesDe(
    String nadadorId, {
    required DateTime desde,
  }) async {
    try {
      final consulta = await firestore
          .collection(coleccionRegistros)
          .where('nadadorId', isEqualTo: nadadorId)
          .leerLoQueHaya();

      final molestias = <MolestiaEnlazada>[];

      for (final documento in consulta.docs) {
        final datos = documento.data();

        final molestia = datos['molestia'];
        if (molestia is! Map) continue;

        final descripcion = molestia['descripcion'];
        if (descripcion is! String || descripcion.trim().isEmpty) continue;

        // Sin fecha no sirve: «le duele el hombro» sin saber de cuándo es no
        // ayuda a decidir el entrenamiento de la semana que viene.
        final fecha = _fecha(datos['registradoEn']) ?? _fecha(datos['cuando']);
        if (fecha == null || !fecha.isAfter(desde)) continue;

        molestias.add(
          MolestiaEnlazada(
            fecha: fecha,
            descripcion: descripcion.trim(),
            zonaDelCuerpo: molestia['zonaDelCuerpo'] is String
                ? molestia['zonaDelCuerpo'] as String
                : '',
          ),
        );
      }

      // De la más reciente a la más vieja: lo de ayer pesa más que lo de hace
      // tres semanas.
      molestias.sort((a, b) => b.fecha.compareTo(a.fecha));
      return molestias;
    } catch (_) {
      // Que no se puedan leer **no quiere decir que no haya**, y por eso la
      // pantalla distingue entre «no contó ninguna» y esto. Aquí se devuelve
      // vacío; decir cuál de las dos cosas es cosa de quien lo pinta.
      return const [];
    }
  }

  /// Quiénes contaron alguna molestia desde [desde]. **Una sola consulta.**
  ///
  /// La misma forma que `nadadoresConRegistros` de la feature 007 y por lo
  /// mismo: la lista de nadadores la pinta el entrenador, y preguntar ficha
  /// por ficha serían N lecturas para dibujar una pantalla.
  ///
  /// Un fallo devuelve el conjunto vacío, igual que `recientesDe`, y por el
  /// mismo motivo declarado: **que no se puedan leer no quiere decir que no
  /// haya**. Quien lo pinta distingue las dos cosas; la lectura completa de
  /// la nadadora sí hace subir el fallo, porque ahí el entrenador está
  /// mirando sus datos y no una marca en una lista.
  @override
  Future<Set<String>> quienesReportaron({required DateTime desde}) async {
    try {
      final consulta = await firestore
          .collection(coleccionRegistros)
          .leerLoQueHaya();

      final quienes = <String>{};

      for (final documento in consulta.docs) {
        final datos = documento.data();

        final nadadorId = datos['nadadorId'];
        if (nadadorId is! String || nadadorId.isEmpty) continue;

        final molestia = datos['molestia'];
        if (molestia is! Map) continue;

        final descripcion = molestia['descripcion'];
        if (descripcion is! String || descripcion.trim().isEmpty) continue;

        final fecha = _fecha(datos['registradoEn']) ?? _fecha(datos['cuando']);
        if (fecha == null || !fecha.isAfter(desde)) continue;

        quienes.add(nadadorId);
      }

      return quienes;
    } catch (_) {
      return const <String>{};
    }
  }
}

/// Una fecha, venga como venga. Si no se entiende, no hay fecha.
///
/// El `TypeError` de un `as Timestamp?` sobre texto es lo que dejó los
/// `Ajustes` de una nadadora girando para siempre en la feature 007.
DateTime? _fecha(Object? valor) => switch (valor) {
  final Timestamp marca => marca.toDate(),
  final DateTime fecha => fecha,
  final String texto => DateTime.tryParse(texto),
  _ => null,
};
