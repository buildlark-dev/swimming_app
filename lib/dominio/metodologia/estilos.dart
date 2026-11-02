/// Estilos de nado, priorización por estilo objetivo y reparto de la sesión.
///
/// Fuentes normativas: secciones 8, 13 y 14 de
/// `docs/metodologia/PROMPT_MAESTRO_V3.4.md`.
library;

enum Estilo {
  libre('Libre'),
  espalda('Espalda'),
  pecho('Pecho'),
  mariposa('Mariposa'),
  combinado('CI'),
  general('General');

  const Estilo(this.nombre);

  final String nombre;

  /// Nombre válido del nado completo (sección 8). Las formas "Libre técnico",
  /// "Pecho asistido" y similares están prohibidas.
  String get nombreDeNado =>
      this == Estilo.combinado ? 'Nado CI' : 'Nado $nombre';

  static Estilo? porNombre(String texto) {
    final buscado = texto.trim().toLowerCase();
    for (final estilo in Estilo.values) {
      if (estilo.nombre.toLowerCase() == buscado) return estilo;
    }
    const equivalencias = <String, Estilo>{
      'crol': Estilo.libre,
      'l': Estilo.libre,
      'e': Estilo.espalda,
      'p': Estilo.pecho,
      'm': Estilo.mariposa,
      'ci': Estilo.combinado,
    };
    return equivalencias[buscado];
  }
}

/// Porcentaje mínimo y máximo de volumen para un estilo dentro de un plan.
class RangoPorcentaje {
  const RangoPorcentaje(this.minimo, this.maximo);

  final int minimo;
  final int maximo;

  bool contiene(double porcentaje) =>
      porcentaje >= minimo && porcentaje <= maximo;

  @override
  String toString() => minimo == maximo ? '$minimo%' : '$minimo-$maximo%';
}

/// Priorización de estilos, aplicable de Precompetitivo en adelante
/// (sección 13).
class PriorizacionEstilos {
  const PriorizacionEstilos({
    required this.estiloObjetivo,
    required this.rangoObjetivo,
    required this.rangoComplementario,
    required this.estilosComplementarios,
  });

  final Estilo estiloObjetivo;
  final RangoPorcentaje rangoObjetivo;
  final RangoPorcentaje rangoComplementario;
  final List<Estilo> estilosComplementarios;

  static const Map<Estilo, PriorizacionEstilos> _tabla = {
    Estilo.libre: PriorizacionEstilos(
      estiloObjetivo: Estilo.libre,
      rangoObjetivo: RangoPorcentaje(80, 85),
      rangoComplementario: RangoPorcentaje(15, 20),
      estilosComplementarios: [Estilo.espalda],
    ),
    Estilo.pecho: PriorizacionEstilos(
      estiloObjetivo: Estilo.pecho,
      rangoObjetivo: RangoPorcentaje(50, 50),
      rangoComplementario: RangoPorcentaje(50, 50),
      estilosComplementarios: [Estilo.libre, Estilo.espalda],
    ),
    Estilo.mariposa: PriorizacionEstilos(
      estiloObjetivo: Estilo.mariposa,
      rangoObjetivo: RangoPorcentaje(50, 50),
      rangoComplementario: RangoPorcentaje(50, 50),
      estilosComplementarios: [Estilo.libre, Estilo.espalda],
    ),
  };

  static PriorizacionEstilos? para(Estilo estiloObjetivo) =>
      _tabla[estiloObjetivo];
}

/// Tipo de parte dentro de una sesión y su porcentaje prescrito del volumen
/// total (sección 14).
enum TipoParte {
  inicial('Inicial', 40),
  central('Central', 50),
  cierre('Final', 10);

  const TipoParte(this.nombre, this.porcentajePrescrito);

  final String nombre;
  final int porcentajePrescrito;
}

/// Dentro de la parte central, el pre-set es el 10% del volumen total y la
/// serie principal el 40% (sección 14).
const int porcentajePreSet = 10;
const int porcentajeSeriePrincipal = 40;
