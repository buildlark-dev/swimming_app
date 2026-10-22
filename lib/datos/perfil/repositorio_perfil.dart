/// Leer el perfil de una cuenta.
///
/// **Solo leer.** Escribirlo es cosa del servidor, porque `usuarios/{uid}`
/// lleva el vínculo entre la cuenta y el nadador, y esa regla no se afloja
/// (decisión D3). La escritura va por `OperacionesDelServidor`.
///
/// De esta lectura depende lo que la app hace nada más entrar: si el perfil
/// está incompleto, se recorren los pasos del alta. Es el mismo camino para
/// una cuenta nueva y para una de las que ya existían, que es lo que evita
/// tener dos pantallas que se parecen.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';

abstract class RepositorioPerfil {
  /// El perfil de una cuenta, o uno vacío si todavía no tiene.
  ///
  /// **Nunca devuelve nulo.** Un perfil vacío es exactamente el estado de las
  /// cuentas creadas antes de la feature 006, y tratarlo como «no hay nada»
  /// obligaría a cada sitio a decidir qué hacer con esa ausencia.
  Future<Perfil> obtener(String uid);
}

class RepositorioPerfilFirestore implements RepositorioPerfil {
  const RepositorioPerfilFirestore(this._db);

  final FirebaseFirestore _db;

  @override
  Future<Perfil> obtener(String uid) async {
    final documento = await _db.collection('usuarios').doc(uid).get();
    final datos = documento.data();
    if (datos == null) return const Perfil();

    return Perfil(
      nombre: (datos['nombre'] as String?) ?? '',
      fechaNacimiento: _comoFecha(datos['fechaNacimiento']),
      pais: datos['pais'] as String?,
      terminos: _comoAceptacion(datos['terminos']),
      correoDelAcudiente: datos['correoDelAcudiente'] as String?,
    );
  }

  /// La fecha puede venir como texto —la escribe el alta— o como marca de
  /// tiempo, si algún día la escribiera otra cosa. Se admiten las dos antes de
  /// que la diferencia cueste un fallo raro.
  static DateTime? _comoFecha(Object? valor) => switch (valor) {
        final String texto => DateTime.tryParse(texto),
        final Timestamp marca => marca.toDate(),
        _ => null,
      };

  static AceptacionDeTerminos? _comoAceptacion(Object? valor) {
    if (valor is! Map) return null;

    final version = valor['version'] as String?;
    final cuando = _comoFecha(valor['aceptadaEn']);
    if (version == null || cuando == null) return null;

    return AceptacionDeTerminos(version: version, aceptadaEn: cuando);
  }
}

/// El de las pruebas y el del modo local.
///
/// En modo local no hay servidor que guarde nada, así que el perfil se queda
/// vacío y el alta no se puede terminar. Es coherente: sin servidor tampoco
/// hay cuentas.
class RepositorioPerfilEnMemoria implements RepositorioPerfil {
  RepositorioPerfilEnMemoria([this._perfiles = const {}]);

  final Map<String, Perfil> _perfiles;

  @override
  Future<Perfil> obtener(String uid) async =>
      _perfiles[uid] ?? const Perfil();
}
