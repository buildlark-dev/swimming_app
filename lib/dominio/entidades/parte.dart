/// Parte de una sesión: inicial, central o final.
///
/// Guarda el texto tal como lo escribió el entrenador y las series que el
/// analizador extrajo de él. **Todo cálculo usa las series** (FR-037); el texto
/// original se conserva solo como referencia, para que el entrenador detecte
/// una interpretación equivocada.
library;

import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Por qué un trozo de texto no se pudo interpretar.
enum MotivoPendiente {
  terminoDesconocido('Término desconocido'),
  estructuraNoReconocida('Estructura no reconocida'),
  ejercicioFueraDeBiblioteca('Ejercicio fuera de la Biblioteca Oficial'),
  ambiguo('Ejercicio ambiguo: falta indicar el estilo'),
  nomenclaturaProhibida('Nomenclatura de nado no admitida');

  const MotivoPendiente(this.descripcion);

  final String descripcion;
}

/// Trozo de texto que el analizador no supo interpretar, con su posición
/// exacta dentro del original para poder resaltarlo.
class FragmentoPendiente {
  const FragmentoPendiente({
    required this.texto,
    required this.posicionInicio,
    required this.posicionFin,
    required this.motivo,
    this.detalle = '',
  });

  final String texto;
  final int posicionInicio;
  final int posicionFin;
  final MotivoPendiente motivo;

  /// Información adicional para el aviso, sin sugerir correcciones.
  final String detalle;

  @override
  String toString() =>
      '"$texto" [$posicionInicio-$posicionFin]: ${motivo.descripcion}'
      '${detalle.isEmpty ? '' : ' ($detalle)'}';
}

class Parte {
  const Parte({
    required this.tipo,
    this.textoOriginal = '',
    this.series = const <Serie>[],
    this.fragmentosPendientes = const <FragmentoPendiente>[],
  });

  final TipoParte tipo;
  final String textoOriginal;
  final List<Serie> series;
  final List<FragmentoPendiente> fragmentosPendientes;

  /// Metros de la parte: suma de los metros de sus series.
  int get metros => series.fold(0, (total, serie) => total + serie.metros);

  /// Metros de trabajo técnico dentro de la parte.
  int get metrosTecnicos => series
      .where((serie) => serie.esTecnica)
      .fold(0, (total, serie) => total + serie.metros);

  bool get tienePendientes => fragmentosPendientes.isNotEmpty;

  Parte copiarCon({
    String? textoOriginal,
    List<Serie>? series,
    List<FragmentoPendiente>? fragmentosPendientes,
  }) {
    return Parte(
      tipo: tipo,
      textoOriginal: textoOriginal ?? this.textoOriginal,
      series: series ?? this.series,
      fragmentosPendientes: fragmentosPendientes ?? this.fragmentosPendientes,
    );
  }

  @override
  String toString() => '${tipo.nombre}: $metros m (${series.length} series)';
}
