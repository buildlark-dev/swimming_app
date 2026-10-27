/// Datos de entrada de una generación: el protocolo de inicio de la sección 5.
///
/// Es lo que hace reproducible el resultado: misma petición, mismo plan
/// (FR-024). No hay semilla ni azar; el determinismo viene de que la petición
/// contiene todo lo que decide el plan.
library;

import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

class PeticionGeneracion {
  const PeticionGeneracion({
    required this.categoria,
    required this.estiloObjetivo,
    required this.pruebaObjetivo,
    this.faseAtr,
    required this.componenteAcentuado,
    required this.diasDisponibles,
    this.fechasSinServicio = const <DateTime>[],
    required this.longitudPiscina,
    required this.duracionSesionMinutos,
    this.diagnosticoTecnico = const <String>[],
    this.lesiones = const <String>[],
    this.nadadoresIds = const <String>[],
  });

  final Categoria categoria;
  final Estilo estiloObjetivo;

  /// 50, 100, 200, 400, 800, fondo. Texto no vacío.
  final String pruebaObjetivo;

  /// Obligatoria si la categoría usa ATR; **prohibida si no** la usa.
  final FaseAtr? faseAtr;

  /// Contenido dominante de la semana. Da nombre al microciclo y orienta la
  /// selección de ejercicios. Es lo que hace que dos semanas consecutivas no
  /// salgan idénticas sin necesidad de azar.
  final String componenteAcentuado;

  final List<DateTime> diasDisponibles;

  /// Festivos o fechas sin servicio: se descuentan de los días disponibles.
  final List<DateTime> fechasSinServicio;

  /// 25 o 50.
  final int longitudPiscina;

  final int duracionSesionMinutos;

  /// Errores técnicos observados. Sin ellos se aplica la progresión estándar y
  /// **no se inventan errores**.
  final List<String> diagnosticoTecnico;

  /// Se registran y se avisan, pero **no modifican el plan**: deducir qué
  /// ejercicio está contraindicado sería simular criterio clínico.
  final List<String> lesiones;

  final List<String> nadadoresIds;

  /// Días que quedan tras descontar los festivos declarados.
  List<DateTime> get diasEfectivos {
    bool estaFuera(DateTime dia) => fechasSinServicio.any(
      (sin) =>
          sin.year == dia.year && sin.month == dia.month && sin.day == dia.day,
    );

    return diasDisponibles.where((dia) => !estaFuera(dia)).toList();
  }

  bool get tieneDiagnostico => diagnosticoTecnico.isNotEmpty;

  /// Dos peticiones con los mismos valores deben producir el mismo plan. Esta
  /// huella permite comprobarlo sin comparar campo por campo.
  String get huella => [
    categoria.name,
    estiloObjetivo.name,
    pruebaObjetivo.trim(),
    faseAtr?.name ?? 'sinFase',
    componenteAcentuado.trim(),
    diasEfectivos.length,
    longitudPiscina,
    duracionSesionMinutos,
    diagnosticoTecnico.join('|'),
  ].join('::');

  PeticionGeneracion copiarCon({
    Categoria? categoria,
    Estilo? estiloObjetivo,
    String? pruebaObjetivo,
    FaseAtr? faseAtr,
    String? componenteAcentuado,
    List<DateTime>? diasDisponibles,
    List<DateTime>? fechasSinServicio,
    int? longitudPiscina,
    int? duracionSesionMinutos,
    List<String>? diagnosticoTecnico,
    List<String>? lesiones,
    List<String>? nadadoresIds,
  }) {
    return PeticionGeneracion(
      categoria: categoria ?? this.categoria,
      estiloObjetivo: estiloObjetivo ?? this.estiloObjetivo,
      pruebaObjetivo: pruebaObjetivo ?? this.pruebaObjetivo,
      faseAtr: faseAtr ?? this.faseAtr,
      componenteAcentuado: componenteAcentuado ?? this.componenteAcentuado,
      diasDisponibles: diasDisponibles ?? this.diasDisponibles,
      fechasSinServicio: fechasSinServicio ?? this.fechasSinServicio,
      longitudPiscina: longitudPiscina ?? this.longitudPiscina,
      duracionSesionMinutos:
          duracionSesionMinutos ?? this.duracionSesionMinutos,
      diagnosticoTecnico: diagnosticoTecnico ?? this.diagnosticoTecnico,
      lesiones: lesiones ?? this.lesiones,
      nadadoresIds: nadadoresIds ?? this.nadadoresIds,
    );
  }

  /// Quita la fase ATR, que `copiarCon` no puede poner a nulo.
  PeticionGeneracion sinFase() => PeticionGeneracion(
    categoria: categoria,
    estiloObjetivo: estiloObjetivo,
    pruebaObjetivo: pruebaObjetivo,
    componenteAcentuado: componenteAcentuado,
    diasDisponibles: diasDisponibles,
    fechasSinServicio: fechasSinServicio,
    longitudPiscina: longitudPiscina,
    duracionSesionMinutos: duracionSesionMinutos,
    diagnosticoTecnico: diagnosticoTecnico,
    lesiones: lesiones,
    nadadoresIds: nadadoresIds,
  );
}
