/// Almacenamiento en el dispositivo.
///
/// Decisión D7 de `specs/003-consumo-del-nadador/research.md`: se guarda sobre
/// `shared_preferences`, un documento JSON por clave. Es lo más pequeño que
/// funciona en web y en móvil sin arrastrar un esquema ni migraciones.
///
/// **Es lo que sostiene la promesa de la feature.** Si esto no persiste de
/// verdad entre reaperturas, el nadador pierde lo que escribió sin conexión, y
/// FR-019 dice que eso no puede pasar.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lo que el dominio necesita de un almacén, sin saber qué hay debajo.
///
/// Se declara aquí y no en `lib/dominio/` porque es una capacidad de
/// infraestructura, no una regla de entrenamiento. El dominio depende de
/// `RepositorioRegistros` y `BandejaDeSalida`, que sí son suyas.
abstract class AlmacenLocal {
  /// Documentos de una colección, por clave.
  Future<Map<String, Map<String, dynamic>>> leerTodo(String coleccion);

  Future<Map<String, dynamic>?> leer(String coleccion, String clave);

  Future<void> escribir(
    String coleccion,
    String clave,
    Map<String, dynamic> documento,
  );

  Future<void> borrar(String coleccion, String clave);

  /// Borra una colección entera. Es lo que hace posible el derecho al borrado
  /// del principio V sin rediseñar nada.
  Future<void> borrarColeccion(String coleccion);

  /// Borra **todo lo de esta cuenta** en el dispositivo.
  ///
  /// Es lo que se llama al cerrar sesión (garantía A7). Borra lo de la cuenta
  /// que este almacén tenga delante y nada más: lo de otra cuenta en el mismo
  /// teléfono sigue donde estaba, porque también es de alguien.
  Future<void> vaciar();
}

/// Fallo al escribir en el dispositivo.
///
/// **Este sí se reporta** (garantía S8 del contrato de sincronización): un
/// fallo de red deja el registro pendiente y se reintenta, pero un fallo de
/// escritura local significa que el dato se perdería, y eso el nadador tiene
/// que saberlo.
class FalloDeAlmacenLocal implements Exception {
  const FalloDeAlmacenLocal(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

class AlmacenPreferencias implements AlmacenLocal {
  AlmacenPreferencias({SharedPreferences? preferencias, this.cuentaId})
      : _inyectadas = preferencias;

  /// De quién es lo que se guarda aquí.
  ///
  /// Todas las claves cuelgan de este identificador, de modo que **dos cuentas
  /// en el mismo dispositivo no comparten ni una** (garantía A9). No es una
  /// precaución teórica: el grupo son hermanos que comparten teléfono, y un
  /// registro del hermano equivocado es un dato personal de un menor en manos
  /// de otro.
  ///
  /// Nulo antes de iniciar sesión. Lo que se escriba entonces vive en una
  /// partición propia que no es de nadie y que nunca se mezcla con la de una
  /// cuenta.
  final String? cuentaId;

  final SharedPreferences? _inyectadas;
  SharedPreferences? _cache;

  Future<SharedPreferences> get _prefs async {
    final inyectadas = _inyectadas;
    if (inyectadas != null) return inyectadas;

    final enCache = _cache;
    if (enCache != null) return enCache;

    try {
      final abiertas = await SharedPreferences.getInstance();
      _cache = abiertas;
      return abiertas;
    } on Exception catch (e) {
      throw FalloDeAlmacenLocal('No se pudo abrir el almacén local: $e');
    }
  }

  /// Clave compuesta. El prefijo evita chocar con lo que guarde otra parte de
  /// la app en las mismas preferencias.
  /// Lo de esta cuenta, y nada más, cuelga de aquí.
  ///
  /// El esquema de claves cambió en la feature 004 al meter la cuenta en
  /// medio. No hace falta migrar nada: hasta esta feature la app solo se usaba
  /// con perfiles de prueba o con los datos del propio entrenador, porque el
  /// principio V lo exigía mientras no existiera el registro de
  /// consentimiento.
  String get _raiz => 'natacion_app/${cuentaId ?? 'sin_cuenta'}/';

  String _clave(String coleccion, String clave) =>
      '${_prefijo(coleccion)}$clave';

  String _prefijo(String coleccion) => '$_raiz$coleccion/';

  @override
  Future<Map<String, Map<String, dynamic>>> leerTodo(String coleccion) async {
    final prefs = await _prefs;
    final prefijo = _prefijo(coleccion);
    final resultado = <String, Map<String, dynamic>>{};

    for (final clave in prefs.getKeys()) {
      if (!clave.startsWith(prefijo)) continue;

      final crudo = prefs.getString(clave);
      if (crudo == null) continue;

      final documento = _decodificar(crudo);
      // Un documento corrupto se omite, no tumba la lectura entera: perder uno
      // es malo, perderlos todos es peor.
      if (documento == null) continue;

      resultado[clave.substring(prefijo.length)] = documento;
    }

    return resultado;
  }

  @override
  Future<Map<String, dynamic>?> leer(String coleccion, String clave) async {
    final prefs = await _prefs;
    final crudo = prefs.getString(_clave(coleccion, clave));
    if (crudo == null) return null;
    return _decodificar(crudo);
  }

  @override
  Future<void> escribir(
    String coleccion,
    String clave,
    Map<String, dynamic> documento,
  ) async {
    final prefs = await _prefs;

    final bool escrito;
    try {
      escrito = await prefs.setString(
        _clave(coleccion, clave),
        jsonEncode(documento),
      );
    } on Exception catch (e) {
      throw FalloDeAlmacenLocal('No se pudo guardar en el dispositivo: $e');
    }

    if (!escrito) {
      throw const FalloDeAlmacenLocal(
        'El dispositivo rechazó la escritura. El progreso no quedó guardado.',
      );
    }
  }

  @override
  Future<void> borrar(String coleccion, String clave) async {
    final prefs = await _prefs;
    await prefs.remove(_clave(coleccion, clave));
  }

  @override
  Future<void> borrarColeccion(String coleccion) async {
    await _borrarBajo(_prefijo(coleccion));
  }

  @override
  Future<void> vaciar() async {
    await _borrarBajo(_raiz);
  }

  Future<void> _borrarBajo(String prefijo) async {
    final prefs = await _prefs;
    final claves = prefs.getKeys().where((k) => k.startsWith(prefijo)).toList();
    for (final clave in claves) {
      await prefs.remove(clave);
    }
  }

  Map<String, dynamic>? _decodificar(String crudo) {
    try {
      final decodificado = jsonDecode(crudo);
      return decodificado is Map<String, dynamic> ? decodificado : null;
    } on FormatException {
      return null;
    }
  }
}
