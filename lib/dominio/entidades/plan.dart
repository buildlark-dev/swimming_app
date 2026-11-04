/// Plan de entrenamiento y su ciclo de vida.
///
/// Fuentes normativas: secciones 11 a 13 de
/// `docs/metodologia/PROMPT_MAESTRO_V3.4.md`.
///
/// **Un `Plan` con una `faseAtr` y varios `microciclos` *es* un mesociclo**
/// (feature 009, decisión D1). El nivel que falta no es ese: es el de encima,
/// `Macrociclo`, que vive en `lib/dominio/macrociclo/macrociclo.dart` y solo
/// guarda referencias —ids de planes— más la estructura que el entrenador
/// confirmó.
///
/// Lo que ya tiene este tipo es exactamente lo que un mesociclo necesita: una
/// fase, sus semanas, sus sesiones, el ciclo `borrador → aprobado →
/// publicado`, la auditoría de la sección 16, `versionAnteriorId` con
/// `crearVersionDesde`, y el sello de metodología. Por eso FR-031 —el
/// mesociclo es la unidad que recibe versión nueva al reajustar— cae sobre un
/// tipo que ya lleva ese linaje probado desde la feature 001, en lugar de
/// obligar a reconstruirlo en un tipo paralelo.
///
/// Queda escrito aquí porque el proyecto llevaba ocho features construyendo
/// mesociclos y llamándolos planes, y sin esta nota la siguiente lo vuelve a
/// descubrir.
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
    this.peticionId,
    this.macrocicloId,
    this.ordenEnElMacrociclo,
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

  /// De qué petición de un nadador salió, si salió de una (feature 008).
  ///
  /// **`OrigenPlan` no se tocó.** Ese campo responde *cómo* se generó —a mano
  /// o con el motor— y la respuesta para un borrador nacido de una petición es
  /// `automatico`, el mismo motor que cualquier otro. *De qué petición* es otra
  /// pregunta, y mezclarlas haría que las auditorías y las pruebas que ya
  /// existen razonaran sobre un tercer origen que se comporta como el segundo.
  ///
  /// Nulo en un plan que el entrenador generó por su cuenta. Es lo que la cola
  /// usa para distinguir los dos.
  final String? peticionId;

  /// Se estampa al aprobar, desde `metodologia.json` (FR-026).
  final String? versionMetodologia;
  final DateTime? fechaAprobacion;

  final List<Justificacion> justificaciones;

  /// Presente cuando el plan nace de editar uno aprobado (FR-025).
  final String? versionAnteriorId;

  /// A qué macrociclo pertenece este mesociclo (feature 009).
  ///
  /// **Nulo en un plan que va por su cuenta**: uno nacido de una petición de la
  /// feature 008, o escrito a mano. Los dos conviven: un macrociclo que llega
  /// después no se traga un plan que ya se firmó solo.
  final String? macrocicloId;

  /// Su posición dentro del macrociclo. Nula cuando va por su cuenta.
  ///
  /// La posición vive aquí y el orden vive también en `Macrociclo.mesociclos`,
  /// que es la lista ordenada. Son dos vistas del mismo hecho a propósito: la
  /// lista es la que manda al leer el macrociclo, y este campo es lo que
  /// permite situar un mesociclo que se leyó solo.
  final int? ordenEnElMacrociclo;

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
    String? peticionId,
    String? macrocicloId,
    int? ordenEnElMacrociclo,
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
      peticionId: peticionId ?? this.peticionId,
      macrocicloId: macrocicloId ?? this.macrocicloId,
      ordenEnElMacrociclo: ordenEnElMacrociclo ?? this.ordenEnElMacrociclo,
    );
  }
}
