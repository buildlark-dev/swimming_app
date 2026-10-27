/// Composición de una sesión: reparte su volumen entre las tres partes y
/// coloca cada zona donde la metodología la ubica.
///
/// **Ubicación de zonas, con preferencia y no con imposición.** El contrato
/// original exigía que la inicial fuera solo A1, y eso no se sostiene: en
/// Transformación la fase prescribe A1 al 30%, mientras que inicial más final
/// suman el 50% del volumen. Obligar a que ambas fueran A1 haría imposible
/// cumplir la distribución de la fase.
///
/// Por eso cada parte declara un **orden de preferencia** de zonas y se llena
/// con lo que haya, empezando por las preferidas. Lo que nunca cede es la
/// estructura 40/50/10 (nivel 2 de la escala de precedencia) ni la
/// distribución total de zonas del microciclo (nivel 5): solo flexiona en qué
/// parte cae cada zona, que la sección 14 no prescribe.
///
/// El orden de preferencia codifica la interconexión de cargas de la sección 4:
/// primero la calidad, luego la carga metabólica.
library;

import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

/// Porcentaje del volumen de la sesión que corresponde al pre-set, dentro del
/// 50% de la parte central.
const int porcentajePreSetDeSesion = 10;

/// Zonas preferidas de cada parte, en orden.
const Map<TipoParte, List<Zona>> preferenciaDeZonas = {
  // Calentamiento y técnica: el nadador está fresco.
  TipoParte.inicial: [Zona.a1, Zona.a2, Zona.a3],
  // La parte central se trata aparte, porque se divide en pre-set y principal.
  TipoParte.central: [
    Zona.resistenciaIntensiva,
    Zona.velocidad,
    Zona.at,
    Zona.a3,
    Zona.a2,
    Zona.a1,
  ],
  // Vuelta a la calma.
  TipoParte.cierre: [Zona.a1, Zona.a2],
};

/// Zonas preferidas del pre-set: técnica de calidad antes de la serie
/// principal.
const List<Zona> preferenciaPreSet = [Zona.a1, Zona.a2, Zona.a3];

/// Metros de una parte dentro de una sesión.
class ReparteParte {
  const ReparteParte({
    required this.tipo,
    required this.metros,
    required this.metrosPorZona,
    this.esPreSet = false,
  });

  final TipoParte tipo;
  final int metros;
  final Map<Zona, int> metrosPorZona;

  /// El pre-set es la primera mitad de la parte central.
  final bool esPreSet;
}

/// Reparte el volumen de una sesión entre sus partes y coloca las zonas.
///
/// Devuelve cuatro bloques: inicial, pre-set, principal y final. El pre-set y
/// el principal componen juntos la parte central.
List<ReparteParte> componerSesion({
  required int volumenSesion,
  required Map<Zona, int> zonasDeSesion,
  required int unidad,
}) {
  // Metros de cada bloque, cuantizados y ajustados para que sumen exacto.
  final objetivoInicial = _cuantizarPorcentaje(
    volumenSesion,
    TipoParte.inicial.porcentajePrescrito,
    unidad,
  );
  final objetivoPreSet = _cuantizarPorcentaje(
    volumenSesion,
    porcentajePreSetDeSesion,
    unidad,
  );
  final objetivoFinal = _cuantizarPorcentaje(
    volumenSesion,
    TipoParte.cierre.porcentajePrescrito,
    unidad,
  );
  final objetivoPrincipal =
      volumenSesion - objetivoInicial - objetivoPreSet - objetivoFinal;

  // Copia mutable del presupuesto de zonas de la sesión.
  final disponible = <Zona, int>{...zonasDeSesion};

  final inicial = _llenar(
    objetivoInicial,
    preferenciaDeZonas[TipoParte.inicial]!,
    disponible,
    unidad,
  );
  final preSet = _llenar(objetivoPreSet, preferenciaPreSet, disponible, unidad);
  final principal = _llenar(
    objetivoPrincipal,
    preferenciaDeZonas[TipoParte.central]!,
    disponible,
    unidad,
  );
  final cierre = _llenar(
    objetivoFinal,
    preferenciaDeZonas[TipoParte.cierre]!,
    disponible,
    unidad,
  );

  return [
    ReparteParte(
      tipo: TipoParte.inicial,
      metros: objetivoInicial,
      metrosPorZona: inicial,
    ),
    ReparteParte(
      tipo: TipoParte.central,
      metros: objetivoPreSet,
      metrosPorZona: preSet,
      esPreSet: true,
    ),
    ReparteParte(
      tipo: TipoParte.central,
      metros: objetivoPrincipal,
      metrosPorZona: principal,
    ),
    ReparteParte(
      tipo: TipoParte.cierre,
      metros: objetivoFinal,
      metrosPorZona: cierre,
    ),
  ];
}

int _cuantizarPorcentaje(int total, int porcentaje, int unidad) {
  final unidades = (total / unidad * porcentaje / 100).round();
  return unidades * unidad;
}

/// Llena un bloque con [objetivo] metros, tomando primero de las zonas
/// preferidas y después de cualquier otra que quede.
///
/// Recurrir a una zona no preferida es una concesión declarada: la estructura
/// de la sesión no cede, y la distribución total del microciclo tampoco.
Map<Zona, int> _llenar(
  int objetivo,
  List<Zona> preferidas,
  Map<Zona, int> disponible,
  int unidad,
) {
  final resultado = <Zona, int>{};
  var faltan = objetivo;

  Iterable<Zona> recorrido() sync* {
    yield* preferidas;
    // Fallback estable: el orden de la metodología.
    for (final zona in Zona.values) {
      if (!preferidas.contains(zona)) yield zona;
    }
  }

  for (final zona in recorrido()) {
    if (faltan <= 0) break;
    final hay = disponible[zona] ?? 0;
    if (hay <= 0) continue;

    final toma = hay < faltan ? hay : faltan;
    resultado[zona] = (resultado[zona] ?? 0) + toma;
    disponible[zona] = hay - toma;
    faltan -= toma;
  }

  return resultado;
}

/// Estilo que domina una sesión, a partir del reparto de estilos del
/// microciclo y del índice de la sesión.
///
/// El recorrido es estable: no hay azar.
Estilo estiloDeSesion({
  required Estilo estiloObjetivo,
  required List<Estilo> complementarios,
  required int indiceSesion,
  required int totalSesiones,
  required double porcentajeObjetivo,
}) {
  if (complementarios.isEmpty) return estiloObjetivo;

  // Las sesiones que corresponden al estilo objetivo, redondeando hacia
  // arriba: el estilo objetivo nunca queda por debajo de lo que le toca.
  final sesionesObjetivo = (totalSesiones * porcentajeObjetivo / 100)
      .ceil()
      .clamp(1, totalSesiones);

  if (indiceSesion < sesionesObjetivo) return estiloObjetivo;

  final resto = indiceSesion - sesionesObjetivo;
  return complementarios[resto % complementarios.length];
}
