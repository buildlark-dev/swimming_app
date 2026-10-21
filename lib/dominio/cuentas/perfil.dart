/// Quién es la persona detrás del correo.
///
/// La feature 004 construyó la cuenta —quién puede entrar y qué puede hacer— y
/// la puerta de consentimiento. Lo que no construyó es **quién es**: hoy hay
/// cuentas reales en uso de las que la app no sabe ni el nombre, ni si tienen
/// nueve años o treinta.
///
/// Un perfil sin fecha de nacimiento es un perfil del que **no se sabe si
/// necesita consentimiento**, y eso no es un hueco de datos: es un riesgo.
///
/// Contrato: `specs/006-alta-de-cuenta/contracts/alta_de_cuenta.md`.
library;

import 'package:natacion_app/dominio/cuentas/edad.dart';

/// Lo que alguien aceptó, y cuándo.
///
/// Un hecho con fecha, no una casilla marcada. La pregunta que alguien hará
/// algún día es «¿qué aceptó esta familia exactamente?», y la única respuesta
/// útil es **el texto que leyeron**, no el de hoy.
class AceptacionDeTerminos {
  const AceptacionDeTerminos({
    required this.version,
    required this.aceptadaEn,
  });

  final String version;
  final DateTime aceptadaEn;

  @override
  bool operator ==(Object other) =>
      other is AceptacionDeTerminos &&
      other.version == version &&
      other.aceptadaEn == aceptadaEn;

  @override
  int get hashCode => Object.hash(version, aceptadaEn);
}

/// Lo que le falta a un perfil para darse por completo.
class FaltaEnElPerfil {
  const FaltaEnElPerfil(this.campo, this.descripcion);

  final String campo;

  /// En español y dirigida a quien la lee, no al programador.
  final String descripcion;

  @override
  String toString() => descripcion;
}

class Perfil {
  const Perfil({
    this.nombre = '',
    this.fechaNacimiento,
    this.pais,
    this.terminos,
    this.correoDelAcudiente,
  });

  /// Sin validar la forma: hay nombres de una letra y nombres con cuatro
  /// apellidos, y no somos quién para decidir cuáles valen.
  final String nombre;

  /// **Solo** para saber si es menor de 18 (FR-010). Nada más la lee, y una
  /// prueba de frontera lo vigila.
  final DateTime? fechaNacimiento;

  /// Para que el club sepa de dónde viene cada nadador, y para nada más
  /// (FR-007). **Nulo es un valor legítimo**: decirlo es opcional.
  final String? pais;

  final AceptacionDeTerminos? terminos;

  /// A dónde va la solicitud de consentimiento, cuando hace falta.
  final String? correoDelAcudiente;

  /// Si hace falta el consentimiento de un acudiente.
  ///
  /// Pregunta a `edad.dart`, que es **el único sitio** donde esto se decide
  /// (garantía A4). Este perfil no lo calcula por su cuenta, aunque tenga el
  /// dato delante.
  bool necesitaAcudienteEn(DateTime referencia) => necesitaAcudiente(
        nacimiento: fechaNacimiento,
        // Un perfil nuevo no tiene declaración: ese campo es de las cuentas
        // de antes de esta feature, y vive en `Nadador` (decisión D2).
        declaraSerMayorDeEdad: null,
        referencia: referencia,
      );

  /// Lo que falta para darlo por completo.
  ///
  /// **El país no está en la lista**, a propósito: es opcional, y un perfil sin
  /// país está completo.
  List<FaltaEnElPerfil> get faltas {
    final faltas = <FaltaEnElPerfil>[];

    if (nombre.trim().isEmpty) {
      faltas.add(const FaltaEnElPerfil('nombre', 'Falta tu nombre'));
    }

    final nacimiento = fechaNacimiento;
    if (nacimiento == null) {
      faltas.add(
        const FaltaEnElPerfil(
          'fechaNacimiento',
          'Falta tu fecha de nacimiento',
        ),
      );
    } else if (!_fechaRazonable(nacimiento)) {
      faltas.add(
        const FaltaEnElPerfil(
          'fechaNacimiento',
          'Esa fecha de nacimiento no puede ser',
        ),
      );
    }

    if (terminos == null) {
      faltas.add(
        const FaltaEnElPerfil(
          'terminos',
          'Falta aceptar los términos y condiciones',
        ),
      );
    }

    return faltas;
  }

  bool get estaCompleto => faltas.isEmpty;

  /// Ni futura ni anterior a 1900.
  ///
  /// Más allá de eso no se opina: una fecha rara es un error de quien escribe,
  /// no un ataque, y rechazarla con sermón no ayuda a nadie.
  static bool _fechaRazonable(DateTime fecha) =>
      !fecha.isAfter(DateTime.now()) && fecha.year >= 1900;

  Perfil copiarCon({
    String? nombre,
    DateTime? fechaNacimiento,
    String? pais,
    AceptacionDeTerminos? terminos,
    String? correoDelAcudiente,
  }) =>
      Perfil(
        nombre: nombre ?? this.nombre,
        fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
        pais: pais ?? this.pais,
        terminos: terminos ?? this.terminos,
        correoDelAcudiente: correoDelAcudiente ?? this.correoDelAcudiente,
      );
}
