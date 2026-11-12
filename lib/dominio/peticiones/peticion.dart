/// La petición de plan: lo que un nadador le pide a su entrenador.
///
/// **No lleva el plan.** Lleva lo que el nadador respondió y en qué estado va;
/// el borrador se genera aparte y vive en `planes`. Esa separación no es
/// ordenada por gusto: lo que el nadador puede leer y lo que no se decide por
/// dónde está guardado, no por lo que la pantalla enseñe.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

import 'package:natacion_app/dominio/metodologia/estilos.dart';

/// Cuánto hacia atrás se miran las molestias que el entrenador ve al abrir una
/// petición.
///
/// **Cuatro semanas**, criterio del entrenador (T066): cubre un microciclo más
/// el anterior. La metodología no fija ningún número, así que está declarado
/// aquí, con nombre, para que cambiarlo sea una edición y una prueba y no una
/// constante suelta en medio de una consulta.
const Duration ventanaDeMolestias = Duration(days: 28);

/// Un día es una fecha, no un instante. Dos respuestas del mismo lunes a horas
/// distintas son el mismo lunes.
DateTime _soloLaFecha(DateTime momento) =>
    DateTime(momento.year, momento.month, momento.day);

/// Un rechazo sin motivo dejaría al nadador sin saber por qué (FR-026).
class RechazoSinMotivo implements Exception {
  const RechazoSinMotivo();

  @override
  String toString() => 'Una petición rechazada necesita un motivo escrito.';
}

/// Aprobar sin plan sería una firma sobre nada.
class AprobacionSinPlan implements Exception {
  const AprobacionSinPlan();

  @override
  String toString() => 'Una petición aprobada tiene que señalar a un plan.';
}

/// Estados que no se corresponden entre sí.
class PeticionIncoherente implements Exception {
  const PeticionIncoherente(this.porQue);

  final String porQue;

  @override
  String toString() => 'Petición incoherente: $porQue';
}

/// Una respuesta del nadador que no cumple lo que el motor necesita.
class RespuestaInvalida implements Exception {
  const RespuestaInvalida(this.campo, this.porQue);

  final String campo;
  final String porQue;

  @override
  String toString() => '$campo: $porQue';
}

/// En qué va la petición. **Solo el entrenador la mueve** (FR-023).
enum EstadoDePeticion {
  esperando('Esperando a tu entrenador'),
  enRevision('Tu entrenador la está viendo'),
  aprobada('Aprobada'),
  rechazada('Tu entrenador respondió');

  const EstadoDePeticion(this.comoLoLeeElNadador);

  /// Lo que el nadador lee, en español y sin jerga.
  ///
  /// **Ninguna de las cuatro promete una fecha** (FR-027). «Tu entrenador
  /// respondió» en lugar de «Rechazada» porque lo que importa es que hay algo
  /// que leer, no la palabra que lo clasifica. Confirmado por el entrenador
  /// (T067).
  final String comoLoLeeElNadador;

  /// Mientras está abierta, el nadador no puede mandar otra (FR-032).
  bool get estaAbierta =>
      this == EstadoDePeticion.esperando || this == EstadoDePeticion.enRevision;
}

/// Lo que el nadador respondió: cinco respuestas y dos confirmaciones.
///
/// **Lo que no está aquí es tan importante como lo que está.** No hay
/// categoría —es del entrenador—, ni fase ATR ni componente acentuado —se
/// derivan—, ni diagnóstico técnico —es observación suya—, ni molestias —se
/// enlazan desde las sesiones, nunca se copian (FR-038)—.
class RespuestasDePeticion {
  factory RespuestasDePeticion({
    required Estilo estiloObjetivo,
    required String pruebaObjetivo,
    required DateTime? fechaDeCompetencia,
    required List<DateTime> diasDisponibles,
    required int duracionSesionMinutos,
    required int longitudPiscina,
  }) {
    if (pruebaObjetivo.trim().isEmpty) {
      throw const RespuestaInvalida('pruebaObjetivo', 'no puede quedar vacía');
    }

    if (diasDisponibles.isEmpty) {
      throw const RespuestaInvalida(
        'diasDisponibles',
        'hace falta al menos un día',
      );
    }

    // Dos veces el mismo día no son dos sesiones: es un día contado dos veces,
    // y el motor repartiría volumen sobre una sesión que no existe.
    final soloFechas = diasDisponibles.map(_soloLaFecha).toList();
    if (soloFechas.toSet().length != soloFechas.length) {
      throw const RespuestaInvalida('diasDisponibles', 'hay un día repetido');
    }

    if (duracionSesionMinutos < 30 || duracionSesionMinutos > 180) {
      throw const RespuestaInvalida(
        'duracionSesionMinutos',
        'tiene que estar entre 30 y 180 minutos',
      );
    }

    if (longitudPiscina != 25 && longitudPiscina != 50) {
      throw const RespuestaInvalida(
        'longitudPiscina',
        'solo hay piscinas de 25 o de 50',
      );
    }

    return RespuestasDePeticion._(
      estiloObjetivo: estiloObjetivo,
      pruebaObjetivo: pruebaObjetivo.trim(),
      fechaDeCompetencia: fechaDeCompetencia,
      diasDisponibles: List.unmodifiable(soloFechas),
      duracionSesionMinutos: duracionSesionMinutos,
      longitudPiscina: longitudPiscina,
    );
  }

  const RespuestasDePeticion._({
    required this.estiloObjetivo,
    required this.pruebaObjetivo,
    required this.fechaDeCompetencia,
    required this.diasDisponibles,
    required this.duracionSesionMinutos,
    required this.longitudPiscina,
  });

  factory RespuestasDePeticion.desdeJson(Map<String, dynamic> datos) {
    final fecha = datos['fechaDeCompetencia'];

    return RespuestasDePeticion(
      estiloObjetivo:
          Estilo.porNombre((datos['estiloObjetivo'] as String?) ?? '') ??
          Estilo.libre,
      pruebaObjetivo: (datos['pruebaObjetivo'] as String?) ?? '',
      fechaDeCompetencia: fecha is String ? DateTime.tryParse(fecha) : null,
      diasDisponibles: [
        for (final dia in (datos['diasDisponibles'] as List<dynamic>? ?? []))
          if (dia is String && DateTime.tryParse(dia) != null)
            DateTime.parse(dia),
      ],
      duracionSesionMinutos:
          (datos['duracionSesionMinutos'] as num?)?.toInt() ?? 0,
      longitudPiscina: (datos['longitudPiscina'] as num?)?.toInt() ?? 0,
    );
  }

  /// Empieza desde la ficha, y el nadador puede cambiarlo para esta petición.
  final Estilo estiloObjetivo;
  final String pruebaObjetivo;

  /// Nula cuando el nadador respondió «no lo sé», que es una respuesta válida
  /// y no un hueco (FR-006). Sin ella no se deriva fase, y la pone el
  /// entrenador.
  final DateTime? fechaDeCompetencia;

  final List<DateTime> diasDisponibles;
  final int duracionSesionMinutos;

  /// 25 o 50.
  final int longitudPiscina;

  Map<String, dynamic> toJson() => {
    'estiloObjetivo': estiloObjetivo.nombre,
    'pruebaObjetivo': pruebaObjetivo,
    'fechaDeCompetencia': fechaDeCompetencia?.toIso8601String(),
    'diasDisponibles': [
      for (final dia in diasDisponibles) dia.toIso8601String(),
    ],
    'duracionSesionMinutos': duracionSesionMinutos,
    'longitudPiscina': longitudPiscina,
  };
}

/// La petición, con su estado.
class PeticionDePlan {
  factory PeticionDePlan({
    required String nadadorId,
    required DateTime enviadaEn,
    required RespuestasDePeticion respuestas,
    required EstadoDePeticion estado,
    String? motivoDelRechazo,
    String? planId,
    DateTime? respondidaEn,
  }) {
    if (nadadorId.trim().isEmpty) {
      throw const PeticionIncoherente('una petición es de alguien');
    }

    final motivo = motivoDelRechazo?.trim();

    if (estado == EstadoDePeticion.rechazada &&
        (motivo == null || motivo.isEmpty)) {
      throw const RechazoSinMotivo();
    }

    if (estado == EstadoDePeticion.aprobada && (planId?.trim() ?? '').isEmpty) {
      throw const AprobacionSinPlan();
    }

    if (estado.estaAbierta) {
      if (motivo != null && motivo.isNotEmpty) {
        throw const PeticionIncoherente(
          'una petición abierta no lleva motivo de rechazo',
        );
      }
      if (respondidaEn != null) {
        throw const PeticionIncoherente(
          'una petición abierta no está respondida',
        );
      }
    }

    return PeticionDePlan._(
      nadadorId: nadadorId.trim(),
      enviadaEn: enviadaEn,
      respuestas: respuestas,
      estado: estado,
      motivoDelRechazo: motivo == null || motivo.isEmpty ? null : motivo,
      planId: planId,
      respondidaEn: respondidaEn,
    );
  }

  const PeticionDePlan._({
    required this.nadadorId,
    required this.enviadaEn,
    required this.respuestas,
    required this.estado,
    required this.motivoDelRechazo,
    required this.planId,
    required this.respondidaEn,
  });

  final String nadadorId;

  /// La pone el servidor al llegar, no el dispositivo (P13).
  final DateTime enviadaEn;

  final RespuestasDePeticion respuestas;
  final EstadoDePeticion estado;

  /// Presente exactamente cuando está rechazada.
  final String? motivoDelRechazo;

  /// El borrador que el entrenador guardó desde ella, si guardó uno.
  final String? planId;

  final DateTime? respondidaEn;

  /// **El identificador es el del nadador**, y eso es lo que hace que «una
  /// petición abierta a la vez» lo imponga el servidor y no la pantalla: con
  /// un identificador aleatorio ninguna regla podría contar las abiertas, y un
  /// límite que solo mantiene la interfaz no es un límite (decisión D6).
  String get id => nadadorId;

  bool get estaAbierta => estado.estaAbierta;
}
