/// El recorrido del alta, y lo que lleva escrito.
///
/// Dos cosas que no son obvias y que están decididas aquí:
///
/// **Lo que va a medias se queda en el dispositivo** (decisión D6). Al servidor
/// no llega un perfil incompleto: un registro a medio escribir allí es algo que
/// hay que limpiar, que aparece en las listas del entrenador y que no significa
/// nada. Lo que se quiere —poder cerrar la app y volver— se consigue igual
/// guardándolo donde ya se guardan las respuestas sin conexión.
///
/// **Los pasos se calculan, no se enumeran.** El paso del acudiente aparece
/// solo si la fecha de nacimiento dice que es menor, y esa fecha se escribe en
/// un paso anterior. Una lista fija obligaría a saltárselo, y saltarse pasos es
/// de donde salen los recorridos que se quedan colgados.
library;

import 'package:flutter/foundation.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/recursos/textos_legales.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/consentimiento/declaracion.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';

/// Cada paso del alta. El orden es el orden.
enum PasoDelAlta {
  nombre('Tu nombre'),
  nacimiento('Tu fecha de nacimiento'),
  pais('Tu país'),
  terminos('Términos y condiciones'),

  /// Solo para menores de edad.
  acudiente('El correo de tu acudiente');

  const PasoDelAlta(this.titulo);

  final String titulo;
}

/// Cómo acabó el alta.
enum ResultadoDelAlta {
  /// Terminó y no hacía falta consentimiento.
  listo,

  /// Terminó y se envió la solicitud al acudiente.
  listoConSolicitud,

  /// Terminó siendo menor y sin dar el correo del acudiente.
  ///
  /// **No es un fallo.** Se entra igual; lo que queda es decirle qué no podrá
  /// hacer hasta que lo dé (FR-019).
  listoSinAcudiente,
}

class EstadoAlta extends ChangeNotifier {
  EstadoAlta({
    required this.operaciones,
    required this.correoDeLaCuenta,
    this.almacen,
    this.nadadorId,
    DateTime Function()? reloj,
  }) : _ahora = reloj ?? DateTime.now;

  /// Nulas sin servidor: entonces el alta no puede guardar nada y lo dice.
  final OperacionesDelServidor? operaciones;

  /// Para comprobar que el correo del acudiente no es el suyo (garantía A12).
  final String correoDeLaCuenta;

  /// Dónde se guarda lo que va a medias. Nulo en las pruebas que no lo miran.
  final AlmacenLocal? almacen;

  final String? nadadorId;
  final DateTime Function() _ahora;

  static const _coleccion = 'alta';
  static const _clave = 'en-curso';

  Perfil _perfil = const Perfil();
  Perfil get perfil => _perfil;

  int _paso = 0;

  /// Los pasos que toca recorrer, calculados con lo que se lleva escrito.
  ///
  /// El del acudiente aparece en cuanto la fecha dice que es menor, y
  /// desaparece si la corrige.
  List<PasoDelAlta> get pasos => [
        PasoDelAlta.nombre,
        PasoDelAlta.nacimiento,
        PasoDelAlta.pais,
        PasoDelAlta.terminos,
        if (esMenor) PasoDelAlta.acudiente,
      ];

  PasoDelAlta get pasoActual => pasos[_paso.clamp(0, pasos.length - 1)];

  int get numeroDePaso => _paso + 1;
  int get totalDePasos => pasos.length;

  bool get esElPrimero => _paso == 0;
  bool get esElUltimo => _paso >= pasos.length - 1;

  /// Si quien se está dando de alta es menor de edad.
  ///
  /// Pregunta al perfil, que pregunta al único sitio que decide esto. Esta
  /// clase **no lo calcula**, aunque tenga la fecha delante (garantía A4).
  bool get esMenor =>
      _perfil.fechaNacimiento != null && _perfil.necesitaAcudienteEn(_ahora());

  // --- Lo que se escribe ------------------------------------------------

  void escribirNombre(String valor) {
    _perfil = _perfil.copiarCon(nombre: valor);
    _guardarLoQueVa();
    notifyListeners();
  }

  void escribirNacimiento(DateTime? valor) {
    _perfil = Perfil(
      nombre: _perfil.nombre,
      fechaNacimiento: valor,
      pais: _perfil.pais,
      terminos: _perfil.terminos,
      correoDelAcudiente: _perfil.correoDelAcudiente,
    );
    _guardarLoQueVa();
    notifyListeners();
  }

  void escribirPais(String? valor) {
    _perfil = Perfil(
      nombre: _perfil.nombre,
      fechaNacimiento: _perfil.fechaNacimiento,
      pais: valor,
      terminos: _perfil.terminos,
      correoDelAcudiente: _perfil.correoDelAcudiente,
    );
    _guardarLoQueVa();
    notifyListeners();
  }

  void aceptarTerminos({required bool aceptados}) {
    _perfil = Perfil(
      nombre: _perfil.nombre,
      fechaNacimiento: _perfil.fechaNacimiento,
      pais: _perfil.pais,
      terminos: aceptados
          ? AceptacionDeTerminos(
              version: versionDeLosTerminos,
              aceptadaEn: _ahora(),
            )
          : null,
      correoDelAcudiente: _perfil.correoDelAcudiente,
    );
    _guardarLoQueVa();
    notifyListeners();
  }

  void escribirCorreoDelAcudiente(String? valor) {
    _perfil = Perfil(
      nombre: _perfil.nombre,
      fechaNacimiento: _perfil.fechaNacimiento,
      pais: _perfil.pais,
      terminos: _perfil.terminos,
      correoDelAcudiente: valor,
    );
    _guardarLoQueVa();
    notifyListeners();
  }

  /// Qué le pasa al correo del acudiente, si le pasa algo.
  MotivoDeCorreoInvalido? get problemaDelAcudiente {
    final correo = _perfil.correoDelAcudiente;
    if (correo == null || correo.trim().isEmpty) return null;

    return DeclaracionDeAcudiente.revisarCorreo(
      correo,
      correoDeLaCuenta: correoDeLaCuenta,
    );
  }

  /// Si el paso que se está mirando se puede dar por bueno.
  bool get elPasoEstaListo => switch (pasoActual) {
        PasoDelAlta.nombre => _perfil.nombre.trim().isNotEmpty,
        PasoDelAlta.nacimiento =>
          _perfil.fechaNacimiento != null && !_faltaLaFecha,
        // Decirlo es opcional: se puede pasar sin elegir nada (FR-009).
        PasoDelAlta.pais => true,
        PasoDelAlta.terminos => _perfil.terminos != null,
        // **Se puede seguir sin darlo** (FR-019). Lo que no se puede es darlo
        // mal.
        PasoDelAlta.acudiente => problemaDelAcudiente == null,
      };

  bool get _faltaLaFecha =>
      _perfil.faltas.any((f) => f.campo == 'fechaNacimiento');

  // --- Moverse ----------------------------------------------------------

  void avanzar() {
    if (!elPasoEstaListo || esElUltimo) return;
    _paso++;
    _guardarLoQueVa();
    notifyListeners();
  }

  void retroceder() {
    if (esElPrimero) return;
    _paso--;
    _guardarLoQueVa();
    notifyListeners();
  }

  // --- Terminar ---------------------------------------------------------

  bool _enviando = false;
  bool get enviando => _enviando;

  String? _fallo;
  String? get fallo => _fallo;

  /// Guarda el perfil y, si hace falta, pide el consentimiento.
  ///
  /// Devuelve cómo acabó, o `null` si no se pudo.
  Future<ResultadoDelAlta?> terminar() async {
    final servidor = operaciones;
    if (servidor == null) {
      _fallo = 'No hay conexión con el servidor. Inténtalo otra vez en un '
          'momento: lo que escribiste no se ha perdido.';
      notifyListeners();
      return null;
    }

    if (!_perfil.estaCompleto) {
      _fallo = _perfil.faltas.first.descripcion;
      notifyListeners();
      return null;
    }

    _enviando = true;
    _fallo = null;
    notifyListeners();

    try {
      // El servidor recalcula la minoría de edad: el cliente podría mentir, y
      // la puerta que viene después trabaja sobre lo que el servidor comprobó.
      final esMenorSegunElServidor = await servidor.guardarPerfil(
        nombre: _perfil.nombre.trim(),
        fechaNacimiento: _perfil.fechaNacimiento!,
        pais: _perfil.pais,
        versionDeTerminos: _perfil.terminos!.version,
      );

      final correo = _perfil.correoDelAcudiente?.trim();

      if (!esMenorSegunElServidor) {
        await _olvidarLoQueVa();
        return ResultadoDelAlta.listo;
      }

      if (correo == null || correo.isEmpty) {
        // **No es un fallo**: se entra igual, y la app dice qué no podrá
        // hacer hasta que lo dé.
        await _olvidarLoQueVa();
        return ResultadoDelAlta.listoSinAcudiente;
      }

      await servidor.pedirConsentimiento(
        nadadorId: nadadorId ?? '',
        canal: correo,
      );

      await _olvidarLoQueVa();
      return ResultadoDelAlta.listoConSolicitud;
    } on FalloDelServidor catch (e) {
      _fallo = e.mensaje;
      return null;
    } finally {
      _enviando = false;
      notifyListeners();
    }
  }

  // --- Lo que va a medias ------------------------------------------------

  /// Recupera un alta interrumpida, si la hay.
  Future<void> recuperar() async {
    final guardado = await almacen?.leer(_coleccion, _clave);
    if (guardado == null) return;

    final fecha = guardado['fechaNacimiento'] as String?;
    final version = guardado['versionDeTerminos'] as String?;
    final aceptadaEn = guardado['terminosAceptadosEn'] as String?;

    _perfil = Perfil(
      nombre: (guardado['nombre'] as String?) ?? '',
      fechaNacimiento: fecha == null ? null : DateTime.tryParse(fecha),
      pais: guardado['pais'] as String?,
      terminos: version == null || aceptadaEn == null
          ? null
          : AceptacionDeTerminos(
              version: version,
              aceptadaEn: DateTime.parse(aceptadaEn),
            ),
      correoDelAcudiente: guardado['correoDelAcudiente'] as String?,
    );
    _paso = (guardado['paso'] as int?) ?? 0;

    notifyListeners();
  }

  void _guardarLoQueVa() {
    // Sin esperar: que el alta vaya fluida importa más que saber al instante
    // si el disco contestó, y si falla se vuelve a escribir en el paso
    // siguiente.
    almacen?.escribir(_coleccion, _clave, {
      'nombre': _perfil.nombre,
      'fechaNacimiento':
          _perfil.fechaNacimiento?.toIso8601String().split('T').first,
      'pais': _perfil.pais,
      'versionDeTerminos': _perfil.terminos?.version,
      'terminosAceptadosEn': _perfil.terminos?.aceptadaEn.toIso8601String(),
      'correoDelAcudiente': _perfil.correoDelAcudiente,
      'paso': _paso,
    });
  }

  Future<void> _olvidarLoQueVa() async {
    await almacen?.borrar(_coleccion, _clave);
  }
}
