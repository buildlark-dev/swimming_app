/// Los cuatro tonos de aviso, y los colores del dominio.
///
/// Viajan en el tema como una extensión, de modo que cualquier pantalla los
/// lee de `Theme.of(context)` igual que lee el esquema de color. Así ninguna
/// necesita conocer `Paleta`, y la regla de que solo `paleta.dart` tiene
/// literales se sostiene sola.
///
/// **Por qué cuatro y no uno** (decisión D5): de los cincuenta y cuatro usos
/// de color semántico que había, treinta y cuatro eran de la familia de error.
/// La app pintaba de rojo todo lo que pedía atención, y solo dos de esos
/// trece sitios eran errores de verdad. Un rojo que sale siempre deja de
/// significar nada: cuando aparezca uno real, nadie lo mirará.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/paleta.dart';

/// Qué clase de aviso es.
enum TonoDeAviso {
  /// Algo que conviene saber. Nadie ha fallado y no hay prisa.
  informativo,

  /// Algo salió bien.
  ///
  /// Aquí va «guardado, se enviará cuando tengas internet»: significa que la
  /// bandeja de salida hizo su trabajo.
  exito,

  /// Algo que mirar, sin que nada se haya roto.
  ///
  /// Avisos de auditoría, modo local, y **el reporte de molestia**: tiene que
  /// encontrarse sin leer todas las observaciones, y a la vez no parecer una
  /// alarma médica. El principio IV prohíbe que la app diagnostique o proponga
  /// conducta, y pintarlo de rojo es una forma de opinar.
  cuidado,

  /// Algo falló y hay que actuar.
  error;

  /// El icono que acompaña al color.
  ///
  /// **El color nunca es la única señal** (FR-015). Quien no distinga colores
  /// tiene que poder reconocer el tono igual.
  IconData get icono => switch (this) {
        TonoDeAviso.informativo => Icons.info_outline,
        TonoDeAviso.exito => Icons.check_circle_outline,
        TonoDeAviso.cuidado => Icons.error_outline,
        TonoDeAviso.error => Icons.cancel_outlined,
      };
}

/// Los colores que Material no trae y esta app necesita.
@immutable
class ColoresDelDominio extends ThemeExtension<ColoresDelDominio> {
  const ColoresDelDominio({
    required this.informativo,
    required this.exito,
    required this.cuidado,
    required this.error,
    required this.zonas,
    required this.borrador,
    required this.aprobado,
    required this.publicado,
  });

  /// Los del modo claro.
  factory ColoresDelDominio.claro() => const ColoresDelDominio(
        informativo: Paleta.informativo,
        exito: Paleta.exito,
        cuidado: Paleta.cuidado,
        error: Paleta.error,
        zonas: Paleta.zonas,
        borrador: Paleta.borrador,
        aprobado: Paleta.aprobado,
        publicado: Paleta.publicado,
      );

  /// Los del modo oscuro.
  factory ColoresDelDominio.oscuro() => const ColoresDelDominio(
        informativo: Paleta.informativoOscuro,
        exito: Paleta.exitoOscuro,
        cuidado: Paleta.cuidadoOscuro,
        error: Paleta.errorOscuro,
        zonas: Paleta.zonasOscuro,
        borrador: Paleta.borradorOscuro,
        aprobado: Paleta.aprobadoOscuro,
        publicado: Paleta.publicadoOscuro,
      );

  final Color informativo;
  final Color exito;
  final Color cuidado;
  final Color error;

  /// Las siete zonas, en el orden de intensidad de la sección 9.
  final List<Color> zonas;

  final Color borrador;
  final Color aprobado;
  final Color publicado;

  /// El color de un tono de aviso.
  Color deTono(TonoDeAviso tono) => switch (tono) {
        TonoDeAviso.informativo => informativo,
        TonoDeAviso.exito => exito,
        TonoDeAviso.cuidado => cuidado,
        TonoDeAviso.error => error,
      };

  /// El color de una zona por su posición en el orden de intensidad.
  ///
  /// Se consulta por índice y no por la entidad `Zona` a propósito: el dominio
  /// no sabe de colores, y es la interfaz la que traduce (principio II).
  Color deZona(int indice) => zonas[indice.clamp(0, zonas.length - 1)];

  @override
  ColoresDelDominio copyWith({
    Color? informativo,
    Color? exito,
    Color? cuidado,
    Color? error,
    List<Color>? zonas,
    Color? borrador,
    Color? aprobado,
    Color? publicado,
  }) =>
      ColoresDelDominio(
        informativo: informativo ?? this.informativo,
        exito: exito ?? this.exito,
        cuidado: cuidado ?? this.cuidado,
        error: error ?? this.error,
        zonas: zonas ?? this.zonas,
        borrador: borrador ?? this.borrador,
        aprobado: aprobado ?? this.aprobado,
        publicado: publicado ?? this.publicado,
      );

  @override
  ColoresDelDominio lerp(ColoresDelDominio? otro, double t) {
    if (otro == null) return this;

    return ColoresDelDominio(
      informativo: Color.lerp(informativo, otro.informativo, t)!,
      exito: Color.lerp(exito, otro.exito, t)!,
      cuidado: Color.lerp(cuidado, otro.cuidado, t)!,
      error: Color.lerp(error, otro.error, t)!,
      zonas: [
        for (var i = 0; i < zonas.length; i++)
          Color.lerp(zonas[i], otro.zonas[i], t)!,
      ],
      borrador: Color.lerp(borrador, otro.borrador, t)!,
      aprobado: Color.lerp(aprobado, otro.aprobado, t)!,
      publicado: Color.lerp(publicado, otro.publicado, t)!,
    );
  }
}

/// Atajo para leerlos desde cualquier pantalla.
extension ColoresDelDominioDeContexto on BuildContext {
  ColoresDelDominio get colores =>
      Theme.of(this).extension<ColoresDelDominio>() ??
      ColoresDelDominio.claro();
}
