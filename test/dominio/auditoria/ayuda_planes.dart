import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/dominio/notacion/analizador.dart';

import '../notacion/ayuda_pruebas.dart';

/// Construye planes de prueba con defectos sembrados a propósito.
///
/// Cada criterio de auditoría necesita un plan que lo viole y otro que lo
/// cumpla: un criterio que nunca falla en las pruebas no está implementado.
class ConstructorPlanes {
  ConstructorPlanes() : _analizador = crearAnalizador();

  final Analizador _analizador;

  /// Sesión con la distribución de zonas indicada, en metros por zona.
  Sesion sesionConZonas(
    Map<Zona, int> metrosPorZona, {
    String microcicloId = 'm1',
    Map<Zona, int> metrosTecnicosPorZona = const {},
    Estilo estilo = Estilo.libre,
    bool completa = true,
  }) {
    final series = <Serie>[];

    metrosPorZona.forEach((zona, metros) {
      if (metros <= 0) return;
      final tecnicos = metrosTecnicosPorZona[zona] ?? 0;
      if (tecnicos > 0) {
        series.add(_serieTecnica(tecnicos, zona, estilo));
      }
      final restantes = metros - tecnicos;
      if (restantes > 0) {
        series.add(Serie(distancia: restantes, zona: zona, estilo: estilo));
      }
    });

    return Sesion(
      microcicloId: microcicloId,
      objetivoTecnico: completa ? 'Técnica de eficiencia' : '',
      objetivoFisiologico: completa ? 'Base aeróbica' : '',
      rpePrevisto: 3,
      partes: [
        Parte(tipo: TipoParte.inicial, series: series),
        const Parte(tipo: TipoParte.central),
        const Parte(tipo: TipoParte.cierre),
      ],
    );
  }

  /// Serie con ejercicio real de la Biblioteca, para que cuente como técnica.
  Serie _serieTecnica(int metros, Zona zona, Estilo estilo) {
    final resultado = _analizador.analizar('$metros VADEO');
    final base = resultado.series.first;
    return base.copiarCon(zona: zona, estilo: estilo);
  }

  /// Sesión construida a partir de texto en notación del entrenador.
  Sesion sesionDeTexto(
    String texto, {
    Zona? zona,
    String microcicloId = 'm1',
    bool completa = true,
  }) {
    final resultado = _analizador.analizar(texto);
    final series = zona == null
        ? resultado.series
        : resultado.series.map((s) => s.copiarCon(zona: zona)).toList();

    return Sesion(
      microcicloId: microcicloId,
      objetivoTecnico: completa ? 'Técnica de eficiencia' : '',
      objetivoFisiologico: completa ? 'Base aeróbica' : '',
      partes: [
        Parte(
          tipo: TipoParte.inicial,
          textoOriginal: texto,
          series: series,
          fragmentosPendientes: resultado.pendientes,
        ),
        const Parte(tipo: TipoParte.central),
        const Parte(tipo: TipoParte.cierre),
      ],
    );
  }

  /// Sesión que cumple a la vez la distribución de zonas, el 50% técnico y el
  /// reparto de estilos 80-85% Libre / 15-20% Espalda del estilo objetivo
  /// Libre (sección 13).
  ///
  /// Sobre 2.000 m, con el reparto de Acumulación de la versión 3.5:
  /// A1 1.100 · A2 460 · A3 200 · AT 100 · Máx 140. Agrupado en el modelo de
  /// tres zonas da **Z1 78% · Z2 15% · Z3 7%**, que cae en el envolvente
  /// piramidal (60-81 / 12-30 / 6-10).
  ///
  /// Lleva 1.000 m técnicos (50%) y 360 m de Espalda (18%).
  Sesion sesionModelo() {
    final series = <Serie>[
      // A1: 1.100 m, de los cuales 840 técnicos y 360 de Espalda.
      _serieTecnica(640, Zona.a1, Estilo.libre),
      _serieTecnica(200, Zona.a1, Estilo.espalda),
      const Serie(distancia: 100, zona: Zona.a1, estilo: Estilo.libre),
      const Serie(distancia: 160, zona: Zona.a1, estilo: Estilo.espalda),
      // A2: 460 m, 160 técnicos.
      _serieTecnica(160, Zona.a2, Estilo.libre),
      const Serie(distancia: 300, zona: Zona.a2, estilo: Estilo.libre),
      // A3: 200 m.
      const Serie(distancia: 200, zona: Zona.a3, estilo: Estilo.libre),
      // AT: 100 m.
      const Serie(distancia: 100, zona: Zona.at, estilo: Estilo.libre),
      // Resistencia intensiva: 140 m. Es el Z3 que el modelo piramidal exige y
      // que la tabla anterior no pedía en Acumulación.
      const Serie(
        distancia: 140,
        zona: Zona.resistenciaIntensiva,
        estilo: Estilo.libre,
      ),
    ];

    return Sesion(
      microcicloId: 'm1',
      objetivoTecnico: 'Técnica de eficiencia',
      objetivoFisiologico: 'Base aeróbica',
      rpePrevisto: 3,
      partes: [
        Parte(tipo: TipoParte.inicial, series: series),
        const Parte(tipo: TipoParte.central),
        const Parte(tipo: TipoParte.cierre),
      ],
    );
  }

  /// Plan de Acumulación que cae en el modelo piramidal publicado, con el 50%
  /// técnico y el reparto de estilos de la sección 13.
  Plan planAcumulacionCorrecto() {
    final sesion = sesionModelo();

    // 2.000 m por sesión: dentro del rango de Precompetitivo.
    return Plan(
      id: 'plan-correcto',
      nombre: 'Microciclo de técnica de eficiencia',
      categoria: Categoria.precompetitivo,
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '100 Libre',
      faseAtr: FaseAtr.acumulacion,
      microciclos: const [
        Microciclo(
          id: 'm1',
          nombre: 'Técnica de eficiencia',
          orden: 1,
          objetivo: 'Economía de nado y base aeróbica',
        ),
      ],
      sesiones: [sesion, sesion, sesion],
    );
  }

  /// Reconstruye un plan declarando su origen.
  ///
  /// `copiarCon` no permite cambiar el origen a propósito (FR-026), así que la
  /// única forma de tener un plan generado es construirlo como tal. Es lo mismo
  /// que hará el generador.
  Plan comoGenerado(Plan plan) => Plan(
        id: plan.id,
        nombre: plan.nombre,
        categoria: plan.categoria,
        estiloObjetivo: plan.estiloObjetivo,
        pruebaObjetivo: plan.pruebaObjetivo,
        longitudPiscina: plan.longitudPiscina,
        fechaInicio: plan.fechaInicio,
        fechaFin: plan.fechaFin,
        faseAtr: plan.faseAtr,
        microciclos: plan.microciclos,
        sesiones: plan.sesiones,
        estado: plan.estado,
        origen: OrigenPlan.automatico,
        versionMetodologia: plan.versionMetodologia,
        fechaAprobacion: plan.fechaAprobacion,
        justificaciones: plan.justificaciones,
        versionAnteriorId: plan.versionAnteriorId,
      );

  /// Igual que el anterior, pero fuera del envolvente piramidal.
  ///
  /// Todo el volumen en Z1 (A1 + A2): 100% frente al máximo publicado de 81%, y
  /// sin nada de Z3 donde el modelo pide del 6 al 10%. Es, por cierto, la forma
  /// que tiene la fase de Acumulación de su macrociclo real.
  Plan planConIntensidadesDesviadas() {
    final sesion = sesionConZonas(
      const {Zona.a1: 1200, Zona.a2: 800},
      metrosTecnicosPorZona: const {Zona.a1: 1000},
    );

    return planAcumulacionCorrecto().copiarCon(
      sesiones: [sesion, sesion, sesion],
    );
  }

  /// Plan de Acumulación con solo el 32% técnico donde se prescribe 50%.
  Plan planConPocaTecnica() {
    final sesion = sesionConZonas(
      const {Zona.a1: 1200, Zona.a2: 500, Zona.a3: 200, Zona.at: 100},
      metrosTecnicosPorZona: const {Zona.a1: 640},
    );

    return planAcumulacionCorrecto().copiarCon(
      sesiones: [sesion, sesion, sesion],
    );
  }
}
