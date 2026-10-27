/// Cálculos sobre una sesión: volumen, reparto entre partes, trabajo técnico y
/// validación contra el rango de la categoría.
///
/// Todo se calcula a partir de las series estructuradas, **nunca del texto sin
/// interpretar** (FR-037).
library;

import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

/// Desviación de una parte respecto al reparto prescrito 40/50/10.
class DesviacionParte {
  const DesviacionParte({
    required this.tipo,
    required this.metros,
    required this.porcentajeReal,
    required this.porcentajePrescrito,
  });

  final TipoParte tipo;
  final int metros;
  final double porcentajeReal;
  final int porcentajePrescrito;

  double get diferencia => porcentajeReal - porcentajePrescrito;

  @override
  String toString() =>
      '${tipo.nombre}: $metros m '
      '(${porcentajeReal.toStringAsFixed(1)}% frente a $porcentajePrescrito%)';
}

/// Resultado de comprobar el volumen contra el rango de la categoría.
class ComprobacionVolumen {
  const ComprobacionVolumen({
    required this.metros,
    required this.categoria,
    required this.dentroDelRango,
    required this.diferencia,
  });

  final int metros;
  final Categoria categoria;
  final bool dentroDelRango;

  /// Metros que sobran (positivo) o faltan (negativo). Cero si está dentro.
  final int diferencia;

  String get descripcion {
    if (dentroDelRango) {
      return '$metros m, dentro del rango de ${categoria.nombre} '
          '(${categoria.volumenPorSesion})';
    }
    if (diferencia > 0) {
      return '$metros m: excede en $diferencia m el máximo de '
          '${categoria.nombre} (${categoria.volumenPorSesion})';
    }
    return '$metros m: faltan ${diferencia.abs()} m para el mínimo de '
        '${categoria.nombre} (${categoria.volumenPorSesion})';
  }
}

class CalculoSesion {
  const CalculoSesion(this.sesion);

  final Sesion sesion;

  int get metros => sesion.metros;

  int get metrosTecnicos => sesion.metrosTecnicos;

  double get porcentajeTecnico => sesion.porcentajeTecnico;

  /// Reparto real frente al prescrito, parte por parte.
  List<DesviacionParte> get repartoDePartes => TipoParte.values
      .map(
        (tipo) => DesviacionParte(
          tipo: tipo,
          metros: sesion.parteDe(tipo).metros,
          porcentajeReal: sesion.porcentajeDe(tipo),
          porcentajePrescrito: tipo.porcentajePrescrito,
        ),
      )
      .toList();

  /// Comprueba el volumen contra el rango de la categoría.
  ComprobacionVolumen comprobarVolumen(Categoria categoria) {
    final rango = categoria.volumenPorSesion;
    return ComprobacionVolumen(
      metros: metros,
      categoria: categoria,
      dentroDelRango: rango.contiene(metros),
      diferencia: rango.desviacion(metros),
    );
  }

  /// Metros por zona de intensidad. Las series sin zona asignada se agrupan
  /// bajo `null`, porque no se pueden repartir por suposición.
  Map<Zona?, int> get metrosPorZona {
    final acumulado = <Zona?, int>{};
    for (final serie in sesion.todasLasSeries) {
      acumulado[serie.zona] = (acumulado[serie.zona] ?? 0) + serie.metros;
    }
    return acumulado;
  }

  /// Metros por estilo. Las series sin estilo se agrupan bajo `null`.
  Map<Estilo?, int> get metrosPorEstilo {
    final acumulado = <Estilo?, int>{};
    for (final serie in sesion.todasLasSeries) {
      acumulado[serie.estilo] = (acumulado[serie.estilo] ?? 0) + serie.metros;
    }
    return acumulado;
  }

  /// Metros que quedaron sin zona asignada. Mientras sean mayores que cero, la
  /// distribución de intensidades no es fiable.
  int get metrosSinZona => metrosPorZona[null] ?? 0;
}
