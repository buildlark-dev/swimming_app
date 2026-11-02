/// Los once criterios de la tabla de auditoría (sección 16).
library;

import 'package:natacion_app/dominio/auditoria/criterio.dart';
import 'package:natacion_app/dominio/auditoria/tolerancia.dart';
import 'package:natacion_app/dominio/calculo/agregacion_plan.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

// ---------------------------------------------------------------------------
// Criterios bloqueantes
// ---------------------------------------------------------------------------

/// C01: todos los ejercicios pertenecen a la Biblioteca Oficial (regla R2).
class CriterioBiblioteca extends Criterio {
  const CriterioBiblioteca();

  @override
  String get id => 'C01_biblioteca';

  @override
  String get nombre =>
      'Todos los ejercicios pertenecen a la Biblioteca Oficial';

  @override
  Severidad get severidad => Severidad.bloqueante;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    final infracciones = <String>[];

    for (final sesion in plan.sesiones) {
      for (final pendiente in sesion.todosLosPendientes) {
        if (pendiente.motivo == MotivoPendiente.ejercicioFueraDeBiblioteca ||
            pendiente.motivo == MotivoPendiente.ambiguo) {
          infracciones.add('"${pendiente.texto}"');
        }
      }
    }

    if (infracciones.isEmpty) {
      return cumpliendo(
        'Los ${plan.sesiones.length} ejercicios usados están en la Biblioteca',
      );
    }

    return fallando(
      '${infracciones.length} referencias ajenas a la Biblioteca: '
      '${infracciones.take(5).join(', ')}'
      '${infracciones.length > 5 ? '…' : ''}',
    );
  }
}

/// C07: nomenclatura de estilos y notación correctas (secciones 8 a 10).
class CriterioNomenclatura extends Criterio {
  const CriterioNomenclatura();

  @override
  String get id => 'C07_nomenclatura';

  @override
  String get nombre => 'Nomenclatura de estilos y notación correctas';

  @override
  Severidad get severidad => Severidad.bloqueante;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    final infracciones = <String>[];

    for (final sesion in plan.sesiones) {
      for (final pendiente in sesion.todosLosPendientes) {
        if (pendiente.motivo == MotivoPendiente.nomenclaturaProhibida) {
          infracciones.add('"${pendiente.texto}"');
        }
      }
    }

    if (infracciones.isEmpty) {
      return cumpliendo('No aparecen formas de nado prohibidas');
    }

    return fallando(
      '${infracciones.length} formas de nado no admitidas: '
      '${infracciones.join(', ')}',
    );
  }
}

/// C08: zonas de intensidad correctas (sección 9).
class CriterioZonas extends Criterio {
  const CriterioZonas();

  @override
  String get id => 'C08_zonas';

  @override
  String get nombre => 'Zonas de intensidad correctas';

  @override
  Severidad get severidad => Severidad.bloqueante;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    final agregacion = AgregacionPlan(plan);
    final sinZona = agregacion.metrosSinZona;

    if (plan.metros == 0) {
      return fallando('El plan no tiene series a las que asignar zona');
    }

    if (sinZona == 0) {
      return cumpliendo(
        'Los ${plan.metros} m del plan tienen zona asignada, '
        'y ninguna serie cuenta en dos zonas',
      );
    }

    final porcentaje = (sinZona * 100) / plan.metros;
    return fallando(
      '$sinZona m sin zona asignada de ${plan.metros} m '
      '(${porcentaje.toStringAsFixed(1)}%). La zona la asigna el entrenador: '
      'no se puede suponer',
    );
  }
}

/// C11: no hay ejercicios ambiguos ni fragmentos sin interpretar.
class CriterioSinAmbiguos extends Criterio {
  const CriterioSinAmbiguos();

  @override
  String get id => 'C11_sin_ambiguos';

  @override
  String get nombre => 'No hay ejercicios ambiguos ni inventados';

  @override
  Severidad get severidad => Severidad.bloqueante;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    var pendientes = 0;
    for (final sesion in plan.sesiones) {
      pendientes += sesion.todosLosPendientes.length;
    }

    final incompletas = plan.sesionesIncompletas.length;

    if (pendientes == 0 && incompletas == 0) {
      return cumpliendo('Todas las sesiones están completas e interpretadas');
    }

    return fallando(
      '$pendientes fragmentos sin interpretar en $incompletas sesiones '
      'incompletas de ${plan.sesiones.length}',
    );
  }
}

// ---------------------------------------------------------------------------
// Criterios justificables
// ---------------------------------------------------------------------------

/// C02: la técnica sigue siendo prioritaria (sección 3).
class CriterioTecnicaPrioritaria extends Criterio {
  const CriterioTecnicaPrioritaria({
    this.tolerancia = Tolerancia.predeterminada,
  });

  final Tolerancia tolerancia;

  @override
  String get id => 'C02_tecnica_prioritaria';

  @override
  String get nombre => 'La técnica sigue siendo prioritaria';

  @override
  Severidad get severidad => Severidad.justificable;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    if (plan.metros == 0) {
      return fallando('El plan no tiene volumen que evaluar');
    }

    final real = plan.porcentajeTecnico;

    if (real <= 0) {
      return fallando(
        'No hay trabajo técnico en el plan. La técnica debe estar presente '
        'durante toda la temporada (sección 3)',
      );
    }

    final fase = plan.faseAtr;
    if (fase == null) {
      return cumpliendo(
        'Trabajo técnico ${real.toStringAsFixed(1)}%. '
        'Sin fase ATR no hay porcentaje prescrito con el que comparar',
      );
    }

    final prescrito = fase.porcentajeTecnico.toDouble();
    final diferencia = real - prescrito;

    if (diferencia >= 0 || tolerancia.admite(diferencia)) {
      return cumpliendo(
        'Trabajo técnico ${real.toStringAsFixed(1)}% frente a '
        '${prescrito.toStringAsFixed(0)}% prescrito en ${fase.nombre}',
      );
    }

    return fallando(
      'Trabajo técnico ${real.toStringAsFixed(1)}% frente a '
      '${prescrito.toStringAsFixed(0)}% prescrito en ${fase.nombre}: '
      '${diferencia.toStringAsFixed(1)} puntos por debajo',
    );
  }
}

/// C03: la fase ATR respeta las intensidades (sección 12).
/// C03: la distribución de intensidades cae en el modelo publicado de la fase.
///
/// **Cambió de unidad en la versión 3.5.** Antes comparaba las seis zonas contra
/// una tabla de porcentajes que el propio documento normativo traía marcada como
/// `[MEJORA PROPUESTA]` y que ninguna fuente respaldaba: Issurin, que era la
/// cita, da concentración de carga y duración de bloques, no distribución de
/// intensidades.
///
/// Ahora compara en las **tres zonas con las que mide la literatura** contra el
/// envolvente publicado del modelo de la fase. Dos consecuencias:
///
/// - **No hace falta tolerancia.** El envolvente es un rango citado, unión de
///   todos los valores publicados para ese modelo. El rango *es* la tolerancia.
/// - **El desglose fino deja de suspender.** Cómo se reparte el envolvente entre
///   las siete zonas es criterio del entrenador, no hallazgo publicado, y no
///   puede sostener un dictamen. Lo informa `repartoPorZona`, que sigue ahí.
class CriterioIntensidadesFase extends Criterio {
  const CriterioIntensidadesFase({this.tolerancia = Tolerancia.predeterminada});

  /// Se conserva por compatibilidad de firma. **Ya no se usa**: el envolvente
  /// publicado sustituyó a la tolerancia elegida a mano.
  final Tolerancia tolerancia;

  @override
  String get id => 'C03_intensidades_fase';

  @override
  String get nombre => 'La distribución cae en el modelo de la fase';

  @override
  Severidad get severidad => Severidad.justificable;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    final fase = plan.faseAtr;
    if (fase == null) {
      if (!plan.categoria.usaAtr) {
        return cumpliendo(
          '${plan.categoria.nombre} no usa el modelo ATR (sección 11)',
        );
      }
      return fallando(
        '${plan.categoria.nombre} usa ATR pero el plan no declara fase',
      );
    }

    if (plan.metros == 0) {
      return fallando('El plan no tiene volumen que distribuir');
    }

    final agregacion = AgregacionPlan(plan);
    if (agregacion.metrosSinZona > 0) {
      return fallando(
        '${agregacion.metrosSinZona} m sin zona: la distribución no es fiable '
        'mientras queden series sin zona asignada',
      );
    }

    final modelo = fase.modelo;
    final reales = agregacion.porcentajePorTid;
    final fuera = <String>[];

    for (final tid in ZonaTid.values) {
      final real = reales[tid] ?? 0;
      final rango = modelo.rangoDe(tid);
      if (rango.contiene(real)) continue;

      final desviacion = rango.desviacion(real);
      fuera.add(
        '${tid.abreviatura} ${real.toStringAsFixed(1)}% frente a $rango '
        '(${desviacion >= 0 ? '+' : ''}${desviacion.toStringAsFixed(1)} puntos)',
      );
    }

    if (fuera.isEmpty) {
      return cumpliendo(
        '${fase.nombre} cae en el modelo ${modelo.nombre}: '
        '${_resumen(reales)}. Envolvente de ${modelo.fuente}',
      );
    }

    return fallando(
      '${fase.nombre} se sale del modelo ${modelo.nombre} '
      '(${modelo.fuente}): ${fuera.join(' · ')}',
    );
  }

  String _resumen(Map<ZonaTid, double> reales) => ZonaTid.values
      .map((t) => '${t.abreviatura} ${(reales[t] ?? 0).toStringAsFixed(1)}%')
      .join(' · ');
}

/// C04: la fase ATR respeta el porcentaje técnico (sección 12).
class CriterioTecnicaFase extends Criterio {
  const CriterioTecnicaFase({this.tolerancia = Tolerancia.predeterminada});

  final Tolerancia tolerancia;

  @override
  String get id => 'C04_tecnica_fase';

  @override
  String get nombre => 'La fase ATR respeta porcentajes técnicos';

  @override
  Severidad get severidad => Severidad.justificable;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    final fase = plan.faseAtr;
    if (fase == null) {
      if (!plan.categoria.usaAtr) {
        return cumpliendo('${plan.categoria.nombre} no usa el modelo ATR');
      }
      return fallando('El plan no declara fase ATR');
    }

    if (plan.metros == 0) {
      return fallando('El plan no tiene volumen que evaluar');
    }

    final real = plan.porcentajeTecnico;
    final prescrito = fase.porcentajeTecnico.toDouble();
    final diferencia = real - prescrito;

    if (tolerancia.admite(diferencia)) {
      return cumpliendo(
        '${real.toStringAsFixed(1)}% técnico frente a '
        '${prescrito.toStringAsFixed(0)}% prescrito en ${fase.nombre}',
      );
    }

    return fallando(
      '${real.toStringAsFixed(1)}% técnico frente a '
      '${prescrito.toStringAsFixed(0)}% prescrito en ${fase.nombre}: '
      '${diferencia >= 0 ? '+' : ''}${diferencia.toStringAsFixed(1)} puntos',
    );
  }
}

/// C05: el volumen respeta la categoría (sección 11).
class CriterioVolumenCategoria extends Criterio {
  const CriterioVolumenCategoria();

  @override
  String get id => 'C05_volumen_categoria';

  @override
  String get nombre => 'El volumen respeta la categoría';

  @override
  Severidad get severidad => Severidad.justificable;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    if (plan.sesiones.isEmpty) {
      return fallando('El plan no tiene sesiones');
    }

    final rango = plan.categoria.volumenPorSesion;
    final fuera = <String>[];

    for (var i = 0; i < plan.sesiones.length; i++) {
      final metros = plan.sesiones[i].metros;
      if (!rango.contiene(metros)) {
        final diferencia = rango.desviacion(metros);
        fuera.add(
          'sesión ${i + 1}: $metros m '
          '(${diferencia > 0 ? '+' : ''}$diferencia m)',
        );
      }
    }

    // Frecuencia semanal por microciclo.
    final esperadas = plan.categoria.sesionesPorSemana;
    final discrepancias = <String>[];
    final porMicrociclo = AgregacionPlan(plan).sesionesPorMicrociclo;
    porMicrociclo.forEach((id, cantidad) {
      if (cantidad != esperadas) {
        discrepancias.add('$id: $cantidad de $esperadas');
      }
    });

    if (fuera.isEmpty && discrepancias.isEmpty) {
      return cumpliendo(
        'Las ${plan.sesiones.length} sesiones están dentro de $rango, '
        'con $esperadas sesiones por microciclo',
      );
    }

    final partes = <String>[];
    if (fuera.isNotEmpty) {
      partes.add(
        '${fuera.length} sesiones fuera del rango $rango de '
        '${plan.categoria.nombre}: ${fuera.take(4).join(', ')}',
      );
    }
    if (discrepancias.isNotEmpty) {
      partes.add(
        'frecuencia semanal distinta de $esperadas en '
        '${discrepancias.length} microciclos: ${discrepancias.join(', ')}',
      );
    }

    return fallando(partes.join('. '));
  }
}

/// C06: existe transferencia hacia la prueba objetivo (sección 13).
class CriterioTransferencia extends Criterio {
  const CriterioTransferencia({this.tolerancia = Tolerancia.predeterminada});

  final Tolerancia tolerancia;

  @override
  String get id => 'C06_transferencia';

  @override
  String get nombre => 'Existe transferencia hacia la prueba objetivo';

  @override
  Severidad get severidad => Severidad.justificable;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    // La priorización de estilos rige «de Precompetitivo en adelante»
    // (sección 13). Iniciación y Tecnificación no la tienen: Tecnificación
    // alterna Pecho y Mariposa por su propia regla.
    if (!plan.categoria.usaAtr) {
      return cumpliendo(
        '${plan.categoria.nombre} no está sujeta a la priorización de estilos '
        '(sección 13, «Precompetitivo en adelante»)',
      );
    }

    final agregacion = AgregacionPlan(plan);
    final reparto = agregacion.repartoDeEstilos;

    if (reparto.isEmpty) {
      return fallando(
        'No hay volumen con estilo declarado, o el estilo objetivo '
        '${plan.estiloObjetivo.nombre} no tiene priorización definida '
        '(sección 13)',
      );
    }

    final objetivo = reparto.first;
    final prioridad = PriorizacionEstilos.para(plan.estiloObjetivo);
    if (prioridad == null) {
      return fallando('Sin priorización para ${plan.estiloObjetivo.nombre}');
    }

    final rango = prioridad.rangoObjetivo;
    final dentro =
        rango.contiene(objetivo.porcentajeReal) ||
        tolerancia.admite(objetivo.diferencia);

    if (dentro) {
      return cumpliendo(
        '${objetivo.etiqueta} al ${objetivo.porcentajeReal.toStringAsFixed(1)}%, '
        'dentro del $rango prescrito',
      );
    }

    return fallando(
      '${objetivo.etiqueta} al ${objetivo.porcentajeReal.toStringAsFixed(1)}% '
      'frente al $rango prescrito para estilo objetivo '
      '${plan.estiloObjetivo.nombre}',
    );
  }
}

/// C09: plan coherente con el modelamiento (sección 4).
class CriterioModelamiento extends Criterio {
  const CriterioModelamiento();

  @override
  String get id => 'C09_modelamiento';

  @override
  String get nombre => 'Plan coherente con el modelamiento';

  @override
  Severidad get severidad => Severidad.justificable;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    if (plan.microciclos.isEmpty) {
      return fallando('El plan no tiene microciclos');
    }

    final malNombrados = plan.microciclos
        .where((m) => !m.nombraElObjetivoReal)
        .map((m) => '"${m.nombre}"')
        .toList();

    final sinObjetivo = plan.microciclos
        .where((m) => m.objetivo.trim().isEmpty)
        .length;

    if (malNombrados.isEmpty && sinObjetivo == 0) {
      return cumpliendo(
        'Los ${plan.microciclos.length} microciclos nombran su objetivo real',
      );
    }

    final partes = <String>[];
    if (malNombrados.isNotEmpty) {
      partes.add(
        '${malNombrados.length} microciclos nombrados solo por su posición: '
        '${malNombrados.join(', ')}. La metodología pide nombrarlos por el '
        'componente acentuado',
      );
    }
    if (sinObjetivo > 0) {
      partes.add('$sinObjetivo microciclos sin objetivo declarado');
    }

    return fallando(partes.join('. '));
  }
}

/// C10: los drills corresponden a errores del diagnóstico (sección 15).
class CriterioDrillsDiagnostico extends Criterio {
  const CriterioDrillsDiagnostico({this.diagnostico = const <String>[]});

  /// Errores técnicos observados en el nadador. Si está vacío, se reporta esa
  /// ausencia sin culpar al plan.
  final List<String> diagnostico;

  @override
  String get id => 'C10_drills_diagnostico';

  @override
  String get nombre => 'Los drills corresponden a errores del diagnóstico';

  @override
  Severidad get severidad => Severidad.justificable;

  @override
  CriterioEvaluado evaluar(Plan plan) {
    if (diagnostico.isEmpty) {
      return cumpliendo(
        'No hay diagnóstico técnico registrado. No se puede comprobar la '
        'correspondencia, y no se le atribuye al plan (sección 15)',
      );
    }

    final ejerciciosUsados = <String>{};
    for (final sesion in plan.sesiones) {
      for (final serie in sesion.todasLasSeries) {
        final ejercicio = serie.ejercicio;
        if (ejercicio != null) {
          ejerciciosUsados.add(ejercicio.errorQueCorrige.toLowerCase());
        }
      }
    }

    if (ejerciciosUsados.isEmpty) {
      return fallando(
        'Hay ${diagnostico.length} errores diagnosticados y el plan no usa '
        'ningún ejercicio técnico',
      );
    }

    final atendidos = diagnostico.where((error) {
      final buscado = error.toLowerCase();
      return ejerciciosUsados.any((corrige) => corrige.contains(buscado));
    }).length;

    if (atendidos > 0) {
      return cumpliendo(
        '$atendidos de ${diagnostico.length} errores diagnosticados se '
        'atacan con ejercicios del plan',
      );
    }

    return fallando(
      'Ninguno de los ${diagnostico.length} errores diagnosticados se ataca '
      'con los ejercicios del plan',
    );
  }
}
