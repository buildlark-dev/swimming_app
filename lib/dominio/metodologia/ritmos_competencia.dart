/// Ritmos de competencia y su clasificación en zonas.
///
/// Fuente normativa: sección 9 de `docs/metodologia/PROMPT_MAESTRO_V3.4.md`.
/// Fundamento y citas: `docs/metodologia/fundamento_zonas.md`.
///
/// **Un ritmo de competencia no es una zona de entrenamiento.** Lo dice la
/// fuente que la metodología cita, Swimming Canada (Vandenbogaerde, 2024):
/// *«Race-Specific training is not a training zone»*. Y precisa que su
/// clasificación depende del nadador:
///
/// > *«for sprint swimmers [it] would be categorized high-intensity, while for
/// > middle-distance swimmers it could be high-intensity or endurance-intensive
/// > dependent on the set, and for distance and open-water swimmers, it will be
/// > endurance-intensive and/or threshold.»*
///
/// Sus hojas, en cambio, escriben `AT / RP8`, `RP8 / Máx` y `RP8` a secas en la
/// columna de intensidad, como si fueran zonas. Por eso la distribución de su
/// macrociclo no se podía calcular, y por eso la tarea T092 quedó bloqueada.
///
/// Lo que sigue **no es una declaración del entrenador: es un cálculo.** Ginn
/// (1993) da que la velocidad crítica es el 90-95% de la velocidad máxima de
/// 400 m, así que el ritmo de 400 queda en el 105-111% de la velocidad crítica.
/// Y Swimming Canada sitúa el umbral en ~ritmo 2000 y la resistencia intensiva
/// en ~ritmo 400. Interpolando entre esos dos anclajes sale la tabla de abajo.
///
/// Es una **regla por defecto**, no una verdad: la propia fuente dice que
/// depende del nadador y del conjunto. El entrenador la sobreescribe en
/// cualquier serie, y entonces manda su corrección.
library;

import 'package:natacion_app/dominio/metodologia/zonas.dart';

enum RitmoCompetencia {
  rp1(
    abreviatura: 'RP1',
    distancia: 100,
    nombre: 'Ritmo 100',
    porcentajeCsMinimo: 115,
    porcentajeCsMaximo: null,
    zonaPorDefecto: Zona.velocidad,
  ),
  rp2(
    abreviatura: 'RP2',
    distancia: 200,
    nombre: 'Ritmo 200',
    porcentajeCsMinimo: 111,
    porcentajeCsMaximo: 115,
    zonaPorDefecto: Zona.velocidad,
  ),
  rp4(
    abreviatura: 'RP4',
    distancia: 400,
    nombre: 'Ritmo 400',
    porcentajeCsMinimo: 105,
    porcentajeCsMaximo: 111,
    zonaPorDefecto: Zona.resistenciaIntensiva,
  ),
  rp8(
    abreviatura: 'RP8',
    distancia: 800,
    nombre: 'Ritmo 800',
    porcentajeCsMinimo: 98,
    porcentajeCsMaximo: 105,
    zonaPorDefecto: Zona.at,
    // Cae justo sobre la frontera del dominio severo: el 100% de velocidad
    // crítica queda dentro de su rango. En un conjunto de volumen alto al ritmo
    // objetivo y descanso corto, el trabajo se va a resistencia intensiva.
    zonaAlternativa: Zona.resistenciaIntensiva,
  ),
  rp15(
    abreviatura: 'RP15',
    distancia: 1500,
    nombre: 'Ritmo 1500',
    porcentajeCsMinimo: 95,
    porcentajeCsMaximo: 100,
    zonaPorDefecto: Zona.at,
  );

  const RitmoCompetencia({
    required this.abreviatura,
    required this.distancia,
    required this.nombre,
    required this.porcentajeCsMinimo,
    required this.porcentajeCsMaximo,
    required this.zonaPorDefecto,
    this.zonaAlternativa,
  });

  final String abreviatura;

  /// Distancia de la prueba, en metros.
  final int distancia;

  final String nombre;

  final int porcentajeCsMinimo;

  /// `null` cuando no hay techo.
  final int? porcentajeCsMaximo;

  /// Zona en que se contabiliza si nadie dice lo contrario.
  final Zona zonaPorDefecto;

  /// Zona a la que pasa cuando el conjunto lleva el trabajo al dominio severo.
  ///
  /// `null` cuando el ritmo no está en una frontera y no hay ambigüedad.
  final Zona? zonaAlternativa;

  /// Verdadero cuando la clasificación depende del conjunto, no solo del ritmo.
  bool get dependeDelConjunto => zonaAlternativa != null;

  /// Cómo se contabiliza este ritmo, con la razón incluida.
  ///
  /// La razón va en la interfaz: el entrenador debe poder ver por qué la app
  /// contó sus 800 m de `RP8` donde los contó, y corregirlo.
  String get razonamiento {
    final techo = porcentajeCsMaximo == null
        ? '>$porcentajeCsMinimo%'
        : '$porcentajeCsMinimo-$porcentajeCsMaximo%';
    final base =
        '$nombre está en el $techo de la velocidad crítica, '
        'así que cuenta como ${zonaPorDefecto.abreviatura}';
    if (!dependeDelConjunto) return '$base.';
    return '$base, y pasa a ${zonaAlternativa!.abreviatura} '
        'cuando el conjunto lo lleva al dominio severo.';
  }

  /// Reconoce un ritmo escrito por el entrenador.
  ///
  /// Admite `RP1500` además de `RP15`, porque las dos formas aparecen en la
  /// sección 9.
  static RitmoCompetencia? porAbreviatura(String texto) {
    final buscado = texto.trim().toUpperCase().replaceAll(' ', '');
    for (final ritmo in RitmoCompetencia.values) {
      if (ritmo.abreviatura == buscado) return ritmo;
    }
    if (buscado == 'RP1500') return RitmoCompetencia.rp15;
    return null;
  }

  /// Zona en que se contabiliza un ritmo, o `null` si el texto no es un ritmo.
  ///
  /// [enDominioSevero] lo decide quien conoce el conjunto: volumen alto al
  /// ritmo objetivo con descanso corto. Por omisión es falso, que es la lectura
  /// conservadora.
  static Zona? zonaDe(String texto, {bool enDominioSevero = false}) {
    final ritmo = porAbreviatura(texto);
    if (ritmo == null) return null;
    if (enDominioSevero && ritmo.zonaAlternativa != null) {
      return ritmo.zonaAlternativa;
    }
    return ritmo.zonaPorDefecto;
  }
}
