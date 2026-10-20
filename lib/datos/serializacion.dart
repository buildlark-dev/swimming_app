/// Conversión entre entidades del dominio y documentos.
///
/// Vive en la capa de datos, no en el dominio: las entidades no saben cómo se
/// guardan. La misma forma sirve para Firestore y para la exportación a JSON,
/// que es la garantía de portabilidad del principio V.
///
/// **No se guardan los derivados** (metros, porcentajes, distribuciones): se
/// recalculan desde las series. Guardar un total sería tener dos fuentes de
/// verdad que pueden discrepar.
library;

import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

// --------------------------------------------------------------------------
// Serie
// --------------------------------------------------------------------------

Map<String, dynamic> serieAJson(Serie serie) => <String, dynamic>{
      'repeticiones': serie.repeticiones,
      'distancia': serie.distancia,
      if (serie.tiempoSalida != null)
        'tiempoSalidaSegundos': serie.tiempoSalida!.inSeconds,
      'implementos': serie.implementos.map((i) => i.name).toList(),
      'modificadores': serie.modificadores.map((m) => m.name).toList(),
      if (serie.ejercicio != null) 'ejercicioNombre': serie.ejercicio!.nombreBase,
      if (serie.ejercicio != null)
        'ejercicioEstilo': serie.ejercicio!.estilo.nombre,
      if (serie.estilo != null) 'estilo': serie.estilo!.nombre,
      if (serie.bloqueTecnico != null)
        'bloqueTecnico': serie.bloqueTecnico!.nombre,
      if (serie.zona != null) 'zona': serie.zona!.abreviatura,
      if (serie.respiracionCada != null)
        'respiracionCada': serie.respiracionCada,
      'origen': serie.origen.name,
      'camposCorregidos': serie.camposCorregidos.toList(),
      'textoOriginal': serie.textoOriginal,
    };

Serie serieDesdeJson(Map<String, dynamic> json, Biblioteca biblioteca) {
  final nombreEjercicio = json['ejercicioNombre'] as String?;
  final estiloEjercicio = json['ejercicioEstilo'] as String?;

  final ejercicio = nombreEjercicio == null
      ? null
      : switch (biblioteca.buscar(
          nombreEjercicio,
          estilo: estiloEjercicio == null
              ? null
              : Estilo.porNombre(estiloEjercicio),
        )) {
          EjercicioEncontrado(:final ejercicio) => ejercicio,
          _ => null,
        };

  return Serie(
    repeticiones: json['repeticiones'] as int? ?? 1,
    distancia: json['distancia'] as int? ?? 0,
    tiempoSalida: json['tiempoSalidaSegundos'] == null
        ? null
        : Duration(seconds: json['tiempoSalidaSegundos'] as int),
    implementos: _porNombres(
      json['implementos'],
      Implemento.values,
      (i) => i.name,
    ),
    modificadores: _porNombres(
      json['modificadores'],
      Modificador.values,
      (m) => m.name,
    ),
    ejercicio: ejercicio,
    estilo: Estilo.porNombre(json['estilo'] as String? ?? ''),
    bloqueTecnico: Estilo.porNombre(json['bloqueTecnico'] as String? ?? ''),
    zona: Zona.porAbreviatura(json['zona'] as String? ?? ''),
    respiracionCada: json['respiracionCada'] as int?,
    origen: OrigenDato.values.firstWhere(
      (o) => o.name == json['origen'],
      orElse: () => OrigenDato.interpretado,
    ),
    camposCorregidos:
        ((json['camposCorregidos'] as List<dynamic>?) ?? const [])
            .cast<String>()
            .toSet(),
    textoOriginal: json['textoOriginal'] as String? ?? '',
  );
}

List<T> _porNombres<T>(
  dynamic lista,
  List<T> valores,
  String Function(T) nombreDe,
) {
  final nombres = ((lista as List<dynamic>?) ?? const []).cast<String>();
  return [
    for (final nombre in nombres)
      ...valores.where((v) => nombreDe(v) == nombre),
  ];
}

// --------------------------------------------------------------------------
// Parte y sesión
// --------------------------------------------------------------------------

Map<String, dynamic> parteAJson(Parte parte) => <String, dynamic>{
      'tipo': parte.tipo.name,
      'textoOriginal': parte.textoOriginal,
      'series': parte.series.map(serieAJson).toList(),
      'fragmentosPendientes': parte.fragmentosPendientes
          .map((f) => <String, dynamic>{
                'texto': f.texto,
                'posicionInicio': f.posicionInicio,
                'posicionFin': f.posicionFin,
                'motivo': f.motivo.name,
                'detalle': f.detalle,
              })
          .toList(),
    };

Parte parteDesdeJson(Map<String, dynamic> json, Biblioteca biblioteca) {
  final tipo = TipoParte.values.firstWhere(
    (t) => t.name == json['tipo'],
    orElse: () => TipoParte.inicial,
  );

  return Parte(
    tipo: tipo,
    textoOriginal: json['textoOriginal'] as String? ?? '',
    series: ((json['series'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((s) => serieDesdeJson(s, biblioteca))
        .toList(),
    fragmentosPendientes:
        ((json['fragmentosPendientes'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((f) => FragmentoPendiente(
                  texto: f['texto'] as String? ?? '',
                  posicionInicio: f['posicionInicio'] as int? ?? 0,
                  posicionFin: f['posicionFin'] as int? ?? 0,
                  motivo: MotivoPendiente.values.firstWhere(
                    (m) => m.name == f['motivo'],
                    orElse: () => MotivoPendiente.terminoDesconocido,
                  ),
                  detalle: f['detalle'] as String? ?? '',
                ))
            .toList(),
  );
}

Map<String, dynamic> sesionAJson(Sesion sesion) => <String, dynamic>{
      if (sesion.microcicloId != null) 'microcicloId': sesion.microcicloId,
      if (sesion.fecha != null)
        'fecha': sesion.fecha!.toIso8601String().split('T').first,
      'objetivoTecnico': sesion.objetivoTecnico,
      'objetivoFisiologico': sesion.objetivoFisiologico,
      if (sesion.rpePrevisto != null) 'rpePrevisto': sesion.rpePrevisto,
      'variablesMonitoreo': sesion.variablesMonitoreo,
      'partes': sesion.partes.map(parteAJson).toList(),
    };

Sesion sesionDesdeJson(
  Map<String, dynamic> json,
  Biblioteca biblioteca, {
  String? id,
}) {
  return Sesion(
    id: id,
    microcicloId: json['microcicloId'] as String?,
    fecha: json['fecha'] == null
        ? null
        : DateTime.tryParse(json['fecha'] as String),
    objetivoTecnico: json['objetivoTecnico'] as String? ?? '',
    objetivoFisiologico: json['objetivoFisiologico'] as String? ?? '',
    rpePrevisto: json['rpePrevisto'] as int?,
    variablesMonitoreo:
        ((json['variablesMonitoreo'] as List<dynamic>?) ?? const [])
            .cast<String>(),
    partes: ((json['partes'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((p) => parteDesdeJson(p, biblioteca))
        .toList(),
  );
}

// --------------------------------------------------------------------------
// Plan
// --------------------------------------------------------------------------

Map<String, dynamic> planAJson(Plan plan, {bool conSesiones = false}) =>
    <String, dynamic>{
      'nombre': plan.nombre,
      'categoria': plan.categoria.nombre,
      'estiloObjetivo': plan.estiloObjetivo.nombre,
      'pruebaObjetivo': plan.pruebaObjetivo,
      'longitudPiscina': plan.longitudPiscina,
      if (plan.fechaInicio != null)
        'fechaInicio': plan.fechaInicio!.toIso8601String().split('T').first,
      if (plan.fechaFin != null)
        'fechaFin': plan.fechaFin!.toIso8601String().split('T').first,
      if (plan.faseAtr != null) 'faseAtr': plan.faseAtr!.nombre,
      'microciclos': plan.microciclos
          .map((m) => <String, dynamic>{
                'id': m.id,
                'nombre': m.nombre,
                'orden': m.orden,
                'objetivo': m.objetivo,
              })
          .toList(),
      'estado': plan.estado.name,
      'origen': plan.origen.name,
      if (plan.versionMetodologia != null)
        'versionMetodologia': plan.versionMetodologia,
      if (plan.fechaAprobacion != null)
        'fechaAprobacion': plan.fechaAprobacion!.toIso8601String(),
      'justificaciones': plan.justificaciones
          .map((j) => <String, dynamic>{
                'criterioId': j.criterioId,
                'texto': j.texto,
                'fecha': j.fecha.toIso8601String(),
              })
          .toList(),
      if (plan.versionAnteriorId != null)
        'versionAnteriorId': plan.versionAnteriorId,
      if (conSesiones)
        'sesiones': plan.sesiones.map(sesionAJson).toList(),
    };

Plan planDesdeJson(
  Map<String, dynamic> json,
  Biblioteca biblioteca, {
  String? id,
  List<Sesion> sesiones = const <Sesion>[],
}) {
  return Plan(
    id: id,
    nombre: json['nombre'] as String? ?? '',
    categoria: Categoria.porNombre(json['categoria'] as String? ?? '') ??
        Categoria.precompetitivo,
    estiloObjetivo:
        Estilo.porNombre(json['estiloObjetivo'] as String? ?? '') ??
            Estilo.libre,
    pruebaObjetivo: json['pruebaObjetivo'] as String? ?? '',
    longitudPiscina: json['longitudPiscina'] as int? ?? 25,
    fechaInicio: json['fechaInicio'] == null
        ? null
        : DateTime.tryParse(json['fechaInicio'] as String),
    fechaFin: json['fechaFin'] == null
        ? null
        : DateTime.tryParse(json['fechaFin'] as String),
    faseAtr: FaseAtr.porNombre(json['faseAtr'] as String? ?? ''),
    microciclos: ((json['microciclos'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((m) => Microciclo(
              id: m['id'] as String? ?? '',
              nombre: m['nombre'] as String? ?? '',
              orden: m['orden'] as int? ?? 0,
              objetivo: m['objetivo'] as String? ?? '',
            ))
        .toList(),
    sesiones: sesiones.isNotEmpty
        ? sesiones
        : ((json['sesiones'] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((s) => sesionDesdeJson(s, biblioteca))
            .toList(),
    estado: EstadoPlan.values.firstWhere(
      (e) => e.name == json['estado'],
      orElse: () => EstadoPlan.borrador,
    ),
    origen: OrigenPlan.values.firstWhere(
      (o) => o.name == json['origen'],
      orElse: () => OrigenPlan.manual,
    ),
    versionMetodologia: json['versionMetodologia'] as String?,
    fechaAprobacion: json['fechaAprobacion'] == null
        ? null
        : DateTime.tryParse(json['fechaAprobacion'] as String),
    justificaciones: ((json['justificaciones'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((j) => Justificacion(
              criterioId: j['criterioId'] as String? ?? '',
              texto: j['texto'] as String? ?? '',
              fecha: DateTime.tryParse(j['fecha'] as String? ?? '') ??
                  DateTime(2026),
            ))
        .toList(),
    versionAnteriorId: json['versionAnteriorId'] as String?,
  );
}

// --------------------------------------------------------------------------
// Nadador
// --------------------------------------------------------------------------

Map<String, dynamic> nadadorAJson(Nadador nadador) => <String, dynamic>{
      'nombre': nadador.nombre,
      if (nadador.fechaNacimiento != null)
        'fechaNacimiento':
            nadador.fechaNacimiento!.toIso8601String().split('T').first,
      if (nadador.declaraSerMayorDeEdad != null)
        'declaraSerMayorDeEdad': nadador.declaraSerMayorDeEdad,
      if (nadador.categoria != null) 'categoria': nadador.categoria!.nombre,
      if (nadador.estiloObjetivo != null)
        'estiloObjetivo': nadador.estiloObjetivo!.nombre,
      'pruebaObjetivo': nadador.pruebaObjetivo,
      'marcas': nadador.marcas
          .map((m) => <String, dynamic>{
                'distancia': m.distancia,
                'estilo': m.estilo.nombre,
                'tiempoMilisegundos': m.tiempo.inMilliseconds,
                'fecha': m.fecha.toIso8601String().split('T').first,
              })
          .toList(),
      'diagnosticoTecnico': nadador.diagnosticoTecnico,
    };

Nadador nadadorDesdeJson(Map<String, dynamic> json, {String? id}) {
  return Nadador(
    id: id,
    nombre: json['nombre'] as String? ?? '',
    fechaNacimiento: json['fechaNacimiento'] == null
        ? null
        : DateTime.tryParse(json['fechaNacimiento'] as String),
    declaraSerMayorDeEdad: json['declaraSerMayorDeEdad'] as bool?,
    categoria: Categoria.porNombre(json['categoria'] as String? ?? ''),
    estiloObjetivo: Estilo.porNombre(json['estiloObjetivo'] as String? ?? ''),
    pruebaObjetivo: json['pruebaObjetivo'] as String? ?? '',
    marcas: ((json['marcas'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((m) => Marca(
              distancia: m['distancia'] as int? ?? 0,
              estilo: Estilo.porNombre(m['estilo'] as String? ?? '') ??
                  Estilo.libre,
              tiempo:
                  Duration(milliseconds: m['tiempoMilisegundos'] as int? ?? 0),
              fecha: DateTime.tryParse(m['fecha'] as String? ?? '') ??
                  DateTime(2026),
            ))
        .toList(),
    diagnosticoTecnico:
        ((json['diagnosticoTecnico'] as List<dynamic>?) ?? const [])
            .cast<String>(),
  );
}

// ---------------------------------------------------------------------------
// Registros del nadador (feature 003)
// ---------------------------------------------------------------------------

/// Serializa un registro de sesión.
///
/// **No incluye ningún dato personal**: ni nombre, ni edad, ni marcas. Solo
/// identificadores opacos y la respuesta del nadador (FR-023, principio V).
Map<String, dynamic> registroAJson(RegistroDeSesion registro) =>
    <String, dynamic>{
      'id': registro.id,
      'nadadorId': registro.nadadorId,
      'planId': registro.planId,
      'sesionId': registro.sesionId,
      'versionDePlan': registro.versionDePlan,
      'realizada': registro.realizada,
      'registradoEn': registro.registradoEn.toIso8601String(),
      if (registro.recibidoEn != null)
        'recibidoEn': registro.recibidoEn!.toIso8601String(),
      if (registro.rpePercibido != null) 'rpePercibido': registro.rpePercibido,
      if (registro.observaciones.isNotEmpty)
        'observaciones': registro.observaciones,
      if (registro.tieneMolestia)
        'molestia': <String, dynamic>{
          'descripcion': registro.molestia!.descripcion,
          'zonaDelCuerpo': registro.molestia!.zonaDelCuerpo,
        },
    };

RegistroDeSesion registroDesdeJson(Map<String, dynamic> json) {
  final molestia = json['molestia'] as Map<String, dynamic>?;

  return RegistroDeSesion(
    nadadorId: json['nadadorId'] as String? ?? '',
    planId: json['planId'] as String? ?? '',
    sesionId: json['sesionId'] as String? ?? '',
    versionDePlan: json['versionDePlan'] as String? ?? '',
    realizada: json['realizada'] as bool? ?? false,
    registradoEn:
        DateTime.tryParse(json['registradoEn'] as String? ?? '') ?? DateTime(2026),
    recibidoEn: DateTime.tryParse(json['recibidoEn'] as String? ?? ''),
    rpePercibido: json['rpePercibido'] as int?,
    observaciones: json['observaciones'] as String? ?? '',
    molestia: molestia == null
        ? null
        : ReporteDeMolestia(
            descripcion: molestia['descripcion'] as String? ?? '',
            zonaDelCuerpo: molestia['zonaDelCuerpo'] as String? ?? '',
          ),
  );
}

/// Serializa una entrada de la bandeja de salida.
///
/// Solo vive en el dispositivo: no tiene sentido fuera de él.
Map<String, dynamic> envioAJson(EnvioPendiente envio) => <String, dynamic>{
      'registroId': envio.registroId,
      'estado': envio.estado.name,
      'intentos': envio.intentos,
      if (envio.ultimoIntento != null)
        'ultimoIntento': envio.ultimoIntento!.toIso8601String(),
      if (envio.ultimoError != null) 'ultimoError': envio.ultimoError,
    };

EnvioPendiente envioDesdeJson(Map<String, dynamic> json) => EnvioPendiente(
      registroId: json['registroId'] as String? ?? '',
      estado: EstadoDeEnvio.values.firstWhere(
        (e) => e.name == json['estado'],
        // Ante un estado desconocido se vuelve a pendiente, nunca a enviado:
        // dar por enviado lo que no se sabe sería perder el dato en silencio.
        orElse: () => EstadoDeEnvio.pendiente,
      ),
      intentos: json['intentos'] as int? ?? 0,
      ultimoIntento: DateTime.tryParse(json['ultimoIntento'] as String? ?? ''),
      ultimoError: json['ultimoError'] as String?,
    );
