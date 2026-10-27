/// Modelos de distribución de intensidades, con sus cifras publicadas.
///
/// Fundamento y citas: `docs/metodologia/fundamento_zonas.md`.
///
/// Sustituyen a la tabla de porcentajes por zona que la versión 3.4 traía
/// marcada como `[MEJORA PROPUESTA]`. Aquella tabla no tenía respaldo: Issurin,
/// que era la fuente citada, da concentración de carga y duración de bloques,
/// **no** porcentajes de distribución de intensidades.
///
/// Cada envolvente es la **unión de todos los valores publicados** para su
/// modelo, así que cualquier cifra que aparezca en la literatura cae dentro. Eso
/// hace innecesaria una tolerancia inventada: **el rango es la tolerancia, y
/// viene citado.**
///
/// Dos advertencias que la literatura trae consigo y conviene no perder:
///
/// 1. La periodización en bloques **no está bien probada en natación**.
///    González-Ravé et al. (2021) terminan pidiendo estudios experimentales de
///    periodización en bloques y en reversa porque no se han ensayado bien en
///    este deporte. El modelo ATR es una elección legítima del entrenador, pero
///    la evidencia que lo respalda viene de otros deportes.
/// 2. De los nueve estudios de esa revisión, **seis son retrospectivos**. Estas
///    cifras son el mejor anclaje disponible, no una ley.
library;

import 'package:natacion_app/dominio/metodologia/zonas.dart';

/// Rango admitido para una zona del modelo de tres, en puntos porcentuales.
class RangoTid {
  const RangoTid(this.minimo, this.maximo);

  final int minimo;
  final int maximo;

  bool contiene(double porcentaje) =>
      porcentaje >= minimo && porcentaje <= maximo;

  /// Cuánto se sale [porcentaje] del rango. Cero si cae dentro.
  double desviacion(double porcentaje) {
    if (porcentaje < minimo) return porcentaje - minimo;
    if (porcentaje > maximo) return porcentaje - maximo;
    return 0;
  }

  @override
  String toString() => '$minimo-$maximo%';
}

enum ModeloTid {
  piramidal(
    nombre: 'Piramidal',
    patron: 'Z1 > Z2 > Z3',
    envolvente: {
      ZonaTid.z1: RangoTid(60, 81),
      ZonaTid.z2: RangoTid(12, 30),
      ZonaTid.z3: RangoTid(6, 10),
    },
    fuente:
        'Filipas et al. 2022 (75-81/12-18/6-8) ∪ '
        'Arroyo-Toledo et al. 2021, en nadadores (60/30/10)',
  ),
  umbral(
    nombre: 'Umbral',
    patron: 'Z1 > Z2 > Z3',
    envolvente: {
      ZonaTid.z1: RangoTid(39, 65),
      ZonaTid.z2: RangoTid(25, 61),
      ZonaTid.z3: RangoTid(0, 10),
    },
    fuente:
        'Stöggl & Sperlich 2014 (39-53/47-61/0) ∪ '
        'Pla et al. 2019, en nadadores (65/25/10)',
  ),
  polarizado(
    nombre: 'Polarizado',
    patron: 'Z1 > Z3 > Z2',
    envolvente: {
      ZonaTid.z1: RangoTid(56, 82),
      ZonaTid.z2: RangoTid(0, 14),
      ZonaTid.z3: RangoTid(15, 33),
    },
    fuente:
        'Stöggl & Sperlich 2014 (56-80/0-14/19-33) ∪ '
        'Pla et al. 2019 (81/4/15) ∪ Arroyo-Toledo et al. 2021 (82/0/18), '
        'los dos últimos en nadadores',
  );

  const ModeloTid({
    required this.nombre,
    required this.patron,
    required this.envolvente,
    required this.fuente,
  });

  final String nombre;

  /// Orden de magnitud entre zonas que define la forma del modelo.
  final String patron;

  final Map<ZonaTid, RangoTid> envolvente;

  /// De dónde salen las cifras. Va en la interfaz: el entrenador tiene derecho
  /// a saber qué respalda lo que la app le exige.
  final String fuente;

  RangoTid rangoDe(ZonaTid zona) => envolvente[zona]!;
}
