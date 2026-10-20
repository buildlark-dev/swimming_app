/// Plan de entrenamiento y su ciclo de vida.
///
/// Fuentes normativas: secciones 11 a 13 de
/// `docs/metodologia/PROMPT_MAESTRO_V3.4.md`.
library;

import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

/// De dónde salió el plan.
///
/// Se fija al crear y **no cambia nunca**: ni al editar, ni al aprobar, ni al
/// crear una versión nueva. Perderlo borraría la trazabilidad que el principio
/// IV de la constitución exige (FR-026).
enum OrigenPlan {
  manual('Escrito a mano'),
  automatico('Generado automáticamente');

  const OrigenPlan(this.nombre);

  final String nombre;

  bool get fueGenerado => this == OrigenPlan.automatico;
}

/// Estado del plan. Solo el entrenador mueve un plan a `aprobado`
/// (principio IV de la constitución).
enum EstadoPlan {
  borrador('Borrador'),
  aprobado('Aprobado'),
  publicado('Publicado');

  const EstadoPlan(this.nombre);

  final String nombre;

  /// Un plan aprobado o publicado es inmutable: editarlo crea una versión
  /// nueva (FR-025).
  bool get esInmutable => this != EstadoPlan.borrador;
}

/// Microciclo: agrupación de sesiones nombrada por su objetivo real y no solo
/// por su posición en la fase (sección 4).
class Microciclo {
  const Microciclo({
    required this.id,
    required this.nombre,
    required this.orden,
    this.objetivo = '',
  });

  final String id;
  final String nombre;
  final int orden;
  final String objetivo;

  /// Nombres que solo indican posición, sin decir qué se acentúa.
  static final RegExp _soloPosicion = RegExp(
    r'^\s*(acumulaci[oó]n|transformaci[oó]n|realizaci[oó]n|microciclo|semana)\s*\d*\s*$',
    caseSensitive: false,
  );

  /// La metodología exige nombrar por el componente acentuado: "técnica de
  /// eficiencia", no "Acumulación 1".
  bool get nombraElObjetivoReal =>
      nombre.trim().isNotEmpty && !_soloPosicion.hasMatch(nombre);
}

/// Justificación escrita que habilita un incumplimiento admisible (FR-023).
class Justificacion {
  const Justificacion({
    required this.criterioId,
    required this.texto,
    required this.fecha,
  });

  final String criterioId;
  final String texto;
  final DateTime fecha;

  /// Una justificación vacía no habilita nada.
  bool get esValida => texto.trim().isNotEmpty;
}

class Plan {
  const Plan({
    this.id,
    required this.nombre,
    required this.categoria,
    required this.estiloObjetivo,
    this.pruebaObjetivo = '',
    this.longitudPiscina = 25,
    this.fechaInicio,
    this.fechaFin,
    this.faseAtr,
    this.microciclos = const <Microciclo>[],
    this.sesiones = const <Sesion>[],
    this.estado = EstadoPlan.borrador,
    this.origen = OrigenPlan.manual,
    this.versionMetodologia,
    this.fechaAprobacion,
    this.justificaciones = const <Justificacion>[],
    this.versionAnteriorId,
  });

  final String? id;
  final String nombre;
  final Categoria categoria;
  final Estilo estiloObjetivo;
  final String pruebaObjetivo;

  /// 25 o 50 metros.
  final int longitudPiscina;

  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  /// Nulo en las categorías que no usan ATR.
  final FaseAtr? faseAtr;

  final List<Microciclo> microciclos;
  final List<Sesion> sesiones;

  final EstadoPlan estado;

  /// De dónde salió el plan. Se fija al construir y no cambia nunca (FR-026).
  final OrigenPlan origen;

  /// Se estampa al aprobar, desde `metodologia.json` (FR-026).
  final String? versionMetodologia;
  final DateTime? fechaAprobacion;

  final List<Justificacion> justificaciones;

  /// Presente cuando el plan nace de editar uno aprobado (FR-025).
  final String? versionAnteriorId;

  int get metros => sesiones.fold(0, (total, sesion) => total + sesion.metros);

  int get metrosTecnicos =>
      sesiones.fold(0, (total, sesion) => total + sesion.metrosTecnicos);

  double get porcentajeTecnico =>
      metros == 0 ? 0 : (metrosTecnicos * 100) / metros;

  List<Sesion> sesionesDe(String microcicloId) =>
      sesiones.where((s) => s.microcicloId == microcicloId).toList();

  List<Sesion> get sesionesIncompletas =>
      sesiones.where((s) => !s.estaCompleta).toList();

  /// La fase ATR solo es admisible en categorías que la usan.
  bool get faseAtrEsAdmisible => faseAtr == null || categoria.usaAtr;

  Justificacion? justificacionDe(String criterioId) {
    for (final justificacion in justificaciones) {
      if (justificacion.criterioId == criterioId) return justificacion;
    }
    return null;
  }

  Plan copiarCon({
    String? id,
    String? nombre,
    Categoria? categoria,
    Estilo? estiloObjetivo,
    String? pruebaObjetivo,
    int? longitudPiscina,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    FaseAtr? faseAtr,
    List<Microciclo>? microciclos,
    List<Sesion>? sesiones,
    EstadoPlan? estado,
    /// Se acepta por uniformidad de la firma, pero NO se aplica: el origen
    /// solo se fija al construir el plan (FR-026).
    OrigenPlan? origen,
    String? versionMetodologia,
    DateTime? fechaAprobacion,
    List<Justificacion>? justificaciones,
    String? versionAnteriorId,
  }) {
    return Plan(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      estiloObjetivo: estiloObjetivo ?? this.estiloObjetivo,
      pruebaObjetivo: pruebaObjetivo ?? this.pruebaObjetivo,
      longitudPiscina: longitudPiscina ?? this.longitudPiscina,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      faseAtr: faseAtr ?? this.faseAtr,
      microciclos: microciclos ?? this.microciclos,
      sesiones: sesiones ?? this.sesiones,
      estado: estado ?? this.estado,
      origen: this.origen,
      versionMetodologia: versionMetodologia ?? this.versionMetodologia,
      fechaAprobacion: fechaAprobacion ?? this.fechaAprobacion,
      justificaciones: justificaciones ?? this.justificaciones,
      versionAnteriorId: versionAnteriorId ?? this.versionAnteriorId,
    );
  }
}
