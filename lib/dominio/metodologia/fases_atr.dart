/// Fases del modelo ATR, con su modelo de distribución y su reparto fino.
///
/// Fuente normativa: sección 12 de `docs/metodologia/PROMPT_MAESTRO_V3.4.md`.
/// Fundamento y citas: `docs/metodologia/fundamento_zonas.md`.
///
/// Cada fase lleva **dos cosas distintas**, y la diferencia es deliberada:
///
/// - **`modelo`**: el modelo de distribución de intensidades que la literatura
///   asocia a esa fase, con su envolvente de tres zonas. Es lo que **se
///   audita**, porque es lo que está publicado.
/// - **`reparto`**: cómo se desglosa ese envolvente entre las siete zonas del
///   entrenador. Es lo que **se usa para generar**. La literatura no llega a ese
///   detalle —mide en tres zonas—, así que el desglose es criterio del
///   entrenador, declarado como tal, dentro de un envolvente publicado.
///
/// Hay una prueba que comprueba que cada `reparto` cae dentro de su propio
/// `modelo`: el criterio del entrenador puede elegir dentro del envolvente, no
/// salirse de él.
///
/// **Por qué este modelo en esta fase.** Dos estudios de caso de nadadores de
/// élite describen la misma progresión —piramidal en el entrenamiento general,
/// umbral y polarizado en el específico, polarizado antes de competir—, que
/// coincide con la lógica de Acumulación → Transformación → Realización.
///
/// **Advertencia de alcance.** González-Ravé et al. (2021) concluyen que el
/// nadador basa su distribución en su prueba principal: velocistas polarizado y
/// umbral, medio fondo umbral y piramidal, fondo principalmente piramidal. Estas
/// fases sirven para **medio fondo y fondo**. Para un velocista de 50 m,
/// Papadimitriou et al. (2025) advierten que ninguno de estos modelos sirve tal
/// cual.
library;

import 'package:natacion_app/dominio/metodologia/modelo_tid.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

enum FaseAtr {
  acumulacion(
    nombre: 'Acumulación',
    objetivos: 'Técnica, economía de nado, base aeróbica',
    modelo: ModeloTid.piramidal,
    // Z1 78 · Z2 15 · Z3 7 — puntos medios de Filipas et al. (2022).
    reparto: {
      Zona.a1: 55,
      Zona.a2: 23,
      Zona.a3: 10,
      Zona.at: 5,
      Zona.resistenciaIntensiva: 7,
      Zona.velocidad: 0,
      Zona.explosivo: 0,
    },
    porcentajeTecnico: 50,
  ),
  transformacion(
    nombre: 'Transformación',
    objetivos: 'Umbral, ritmo competitivo, velocidad-resistencia',
    modelo: ModeloTid.umbral,
    // Z1 65 · Z2 25 · Z3 10 — las cifras del ensayo de Pla et al. (2019),
    // hecho en nadadores.
    reparto: {
      Zona.a1: 35,
      Zona.a2: 30,
      Zona.a3: 12,
      Zona.at: 13,
      Zona.resistenciaIntensiva: 8,
      Zona.velocidad: 2,
      Zona.explosivo: 0,
    },
    porcentajeTecnico: 30,
  ),
  realizacion(
    nombre: 'Realización',
    objetivos: 'Velocidad, afinación, competencia',
    modelo: ModeloTid.polarizado,
    // Z1 81 · Z2 4 · Z3 15 — las cifras del ensayo de Pla et al. (2019).
    // El A1 alto no es un error: polarizado significa mucho suave y algo muy
    // duro, con poco en medio, y encaja con la bajada de volumen del taper.
    reparto: {
      Zona.a1: 50,
      Zona.a2: 31,
      Zona.a3: 0,
      Zona.at: 4,
      Zona.resistenciaIntensiva: 5,
      Zona.velocidad: 7,
      Zona.explosivo: 3,
    },
    porcentajeTecnico: 20,
  );

  const FaseAtr({
    required this.nombre,
    required this.objetivos,
    required this.modelo,
    required this.reparto,
    required this.porcentajeTecnico,
  });

  final String nombre;
  final String objetivos;

  /// Modelo publicado que se audita.
  final ModeloTid modelo;

  /// Desglose del envolvente entre las siete zonas, para generar.
  final Map<Zona, int> reparto;

  /// Porcentaje del volumen total que debe ser trabajo técnico.
  ///
  /// Es criterio del entrenador y no sale de la literatura de distribución de
  /// intensidades, que no mide trabajo técnico. El escenario G14 lo validó
  /// contra su macrociclo real: sus hojas de Acumulación declaran «téc ~50%».
  final int porcentajeTecnico;

  /// Mantiene el nombre anterior para no romper lo que ya llamaba así al
  /// reparto fino.
  Map<Zona, int> get distribucion => reparto;

  /// Suma del reparto. Debe ser 100 en todas las fases; hay prueba.
  int get sumaDistribucion =>
      reparto.values.fold(0, (total, valor) => total + valor);

  int prescritoPara(Zona zona) => reparto[zona] ?? 0;

  /// Porcentaje que el reparto asigna a una zona del modelo de tres.
  int prescritoParaTid(ZonaTid tid) {
    var total = 0;
    for (final entrada in reparto.entries) {
      if (entrada.key.tid == tid) total += entrada.value;
    }
    return total;
  }

  /// Verdadero si el reparto fino cae dentro del envolvente publicado.
  bool get repartoCabeEnElModelo {
    for (final tid in ZonaTid.values) {
      if (!modelo.rangoDe(tid).contiene(prescritoParaTid(tid).toDouble())) {
        return false;
      }
    }
    return true;
  }

  /// Duración admitida del bloque, en semanas, según Issurin (2010).
  ///
  /// **No se usa para suspender nada, y la razón importa.** La literatura de
  /// natación que se revisó para la versión 3.5 **no respalda** estos rangos:
  ///
  /// - El estudio de caso de un nadador de 400 estilos usa fases
  ///   general/específica/competitiva de 6/10/5, 4/7/10 y 3/10/3 semanas.
  ///   Ninguna de sus fases específicas cabe en los 2-4 de Issurin.
  /// - Maglischo (2003) da taper de 1-3 semanas para medio fondo y fondo.
  /// - Un estudio de cohorte de 20 años asocia el rendimiento máximo a
  ///   macrociclos de 14-15 semanas.
  ///
  /// El macrociclo real del entrenador tiene 14 semanas y 2 de taper: coincide
  /// con la literatura de natación y se aparta de Issurin, que es literatura de
  /// otros deportes. Así que esto **avisa**, con la fuente a la vista, y es él
  /// quien decide.
  (int, int) get semanasSegunIssurin => switch (this) {
    FaseAtr.acumulacion => (2, 6),
    FaseAtr.transformacion => (2, 4),
    // Issurin da 8-15 días para el bloque de realización.
    FaseAtr.realizacion => (1, 2),
  };

  /// Verdadero si [semanas] cabe en el rango de Issurin para este bloque.
  bool duracionSegunIssurin(int semanas) {
    final (minimo, maximo) = semanasSegunIssurin;
    return semanas >= minimo && semanas <= maximo;
  }

  static FaseAtr? porNombre(String nombre) {
    final buscado = nombre.trim().toLowerCase();
    for (final fase in FaseAtr.values) {
      if (fase.nombre.toLowerCase() == buscado) return fase;
    }
    return null;
  }
}
