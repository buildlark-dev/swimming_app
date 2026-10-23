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

/// Reintenta la lectura antes de darla por perdida.
///
/// **Una lectura que falla no significa que no haya perfil.** Recién iniciada
/// la sesión, el cliente de Firestore puede no llevar todavía el token nuevo, y
/// la lectura se rechaza por reglas. La puerta del perfil interpretaba ese
/// fallo como «no sabemos quién eres» y mandaba al alta a alguien que acababa
/// de entrar; cerrar la PWA y abrirla de nuevo lo arreglaba, que es justo la
/// firma de una carrera entre el token y la lectura.
///
/// **Un perfil vacío no se reintenta.** Es el estado legítimo de toda cuenta
/// creada antes de la feature 006, y reintentarlo retrasaría el alta de quien
/// sí tiene que recorrerla.
///
/// Y no insiste para siempre: con el servidor caído el fallo tiene que llegar,
/// porque es lo que deja ver la salida «Entrar de todos modos».
class RepositorioPerfilConReintentos implements RepositorioPerfil {
  const RepositorioPerfilConReintentos(
    this._debajo, {
    this.intentos = 3,
    Future<void> Function(Duration)? espera,
  }) : _espera = espera ?? Future.delayed;

  final RepositorioPerfil _debajo;

  /// Contando el primero. Tres intentos en poco más de un segundo y medio: lo
  /// que tarda un token en propagarse, no lo que tarda alguien en rendirse.
  final int intentos;

  final Future<void> Function(Duration) _espera;

  static const _pausas = [
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200),
  ];

  @override
  Future<Perfil> obtener(String uid) async {
    for (var intento = 1; intento <= intentos; intento++) {
      try {
        return await _debajo.obtener(uid);
      } catch (_) {
        if (intento == intentos) rethrow;
        await _espera(_pausas[(intento - 1).clamp(0, _pausas.length - 1)]);
      }
    }
    // Inalcanzable: el último intento o devuelve o relanza.
    throw StateError('sin intentos');
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
