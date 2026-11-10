/// Los registros del nadador, leídos **de su teléfono y del servidor**.
///
/// **Esto faltaba, y lo encontró el recorrido de la feature 009.** La pantalla
/// del macrociclo recibía `RegistrosLocales`, así que lo que el nadador ve
/// —«Sesiones cumplidas: 2 de 10»— salía solo del almacén de ese dispositivo.
/// El servidor lo tenía: desde la feature 003 los registros se envían y
/// `RegistrosFirestore` sabe leerlos. Nadie los leía para él.
///
/// Se notaba en el sitio peor: cambiar de móvil o reinstalar dejaba su cuenta
/// en cero, con el dato a salvo en el servidor, justo debajo de una frase que
/// le dice «Lo que ya habías anotado sigue ahí».
///
/// **Escribir no cambia.** Anotar sigue yendo al dispositivo y encolándose
/// después (garantía G1 de la feature 003): a pie de piscina no se espera a la
/// red, y eso no se toca. Lo que cambia es leer.
library;

import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class RegistrosDeLasDosPartes implements RepositorioRegistros {
  const RegistrosDeLasDosPartes({required this.local, required this.servidor});

  /// El almacén de este teléfono. **Manda.**
  final RepositorioRegistros local;

  /// Lo que el servidor guarda de él, de este y de cualquier otro aparato.
  final RepositorioRegistros servidor;

  /// Lo que el servidor tenga, **sin que un fallo cueste la pantalla**.
  ///
  /// Sin red se devuelve lo local y no se nota. Lo contrario sería dejarle sin
  /// su plan por un problema de cobertura, que es justo lo que la garantía A8
  /// de la feature 003 prohíbe.
  Future<List<RegistroDeSesion>> _delServidor(
    Future<List<RegistroDeSesion>> Function() pedir,
  ) async {
    try {
      return await pedir();
    } on FalloDeDatos {
      return const [];
    }
  }

  @override
  Future<RegistroDeSesion?> obtener(String registroId) async {
    // Lo local primero: si está, es su última palabra.
    final suyo = await local.obtener(registroId);
    if (suyo != null) return suyo;

    try {
      return await servidor.obtener(registroId);
    } on FalloDeDatos {
      return null;
    }
  }

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async {
    final delServidor = await _delServidor(
      () => servidor.obtenerDePlan(nadadorId, planId),
    );
    final deAqui = await local.obtenerDePlan(nadadorId, planId);

    // **Gana lo local, y por eso se pone después.** Lo que todavía no se ha
    // enviado es lo más reciente que él escribió; si mandara el servidor,
    // vería cómo una respuesta recién puesta vuelve atrás sola.
    final porId = <String, RegistroDeSesion>{
      for (final registro in delServidor) registro.id: registro,
      for (final registro in deAqui) registro.id: registro,
    };

    return List.unmodifiable(porId.values);
  }

  /// **Al dispositivo y a nadie más** (garantía G1).
  ///
  /// Mandar al servidor desde aquí haría que anotar dependiera de la red. De
  /// eso se encarga la bandeja de salida, después y por su cuenta.
  @override
  Future<void> guardar(RegistroDeSesion registro) => local.guardar(registro);

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) =>
      local.exportar(nadadorId);

  /// **Solo el dispositivo, y es deliberado.**
  ///
  /// `firestore.rules`: «un registro no se borra desde el cliente. El derecho
  /// al borrado del principio V se ejerce por la vía del servidor, que puede
  /// dejar constancia de que se ejerció». Juntar las dos lecturas no puede
  /// abrir esa puerta por la espalda.
  @override
  Future<void> eliminarDe(String nadadorId) => local.eliminarDe(nadadorId);

  @override
  Future<Set<String>> nadadoresConRegistros() => local.nadadoresConRegistros();
}
