/// El borrador que sale de una petición.
///
/// **Lo compone el motor determinista de la feature 002**, con las reglas ya
/// codificadas y sin modelo de lenguaje en ningún campo. Lo que esta función
/// hace es juntar las tres fuentes de las once entradas que el motor exige:
///
/// - **las respuestas del nadador**: días, duración, piscina, estilo y prueba;
/// - **su ficha**: categoría y diagnóstico técnico, que son del entrenador;
/// - **lo derivado**: la fase ATR y el componente acentuado.
///
/// Y hace una cosa más, que es la que importa: cuando la categoría usa ATR y
/// no hay fecha utilizable, **no genera nada**. La regla R3 dice que ante
/// datos faltantes se pregunta, no se supone, y una fase inventada sería una
/// suposición metodológica con la firma del entrenador encima.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/generacion/generador.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/peticiones/componente_por_fase.dart';
import 'package:natacion_app/dominio/peticiones/fase_por_fecha.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';

/// Lo que el entrenador tiene delante al abrir una petición.
class BorradorDePeticion {
  const BorradorDePeticion({
    required this.fase,
    required this.resultado,
    required this.faltaLaFase,
  });

  /// Qué fase salió y **por qué**. Va siempre, incluso cuando no hay fase:
  /// una fase derivada que no se puede ver ni corregir sería criterio
  /// delegado por la puerta de atrás.
  final FaseDerivada fase;

  /// Nulo cuando no se pudo generar porque falta la fase. Si el motor rechaza
  /// la petición por otra cosa, aquí viene su `GeneracionImposible` con los
  /// impedimentos, que es información para el entrenador y no un fallo mudo.
  final ResultadoGeneracion? resultado;

  /// Verdadero cuando lo único que falta es que el entrenador ponga la fase.
  final bool faltaLaFase;
}

/// Arma la petición del motor y genera, o explica por qué todavía no.
BorradorDePeticion generarDesdePeticion({
  required PeticionDePlan peticion,
  required Nadador ficha,
  required Biblioteca biblioteca,
  required String versionMetodologia,
  required DateTime hoy,
  IndiceTerminos? indice,

  /// La que el entrenador eligió a mano, si la cambió. Manda sobre la
  /// derivada: él decide, la app ahorra tiempo (FR-017).
  FaseAtr? faseElegida,
}) {
  final categoria = ficha.categoria ?? Categoria.iniciacion;
  final respuestas = peticion.respuestas;

  final derivada = faseElegida != null
      ? FaseDerivada(
          fase: categoria.usaAtr ? faseElegida : null,
          diasHastaLaCompetencia: null,
          porQue: categoria.usaAtr
              ? '${faseElegida.nombre}, porque la eligió el entrenador.'
              : 'Sin fase: ${categoria.nombre} no trabaja por fases ATR.',
        )
      : faseParaCompetencia(
          fechaDeCompetencia: respuestas.fechaDeCompetencia,
          hoy: hoy,
          categoria: categoria,
        );

  // **Aquí no se genera a medias.** El motor exige fase cuando la categoría la
  // usa; sin fecha utilizable no hay de dónde sacarla, y ponerle una sería
  // decidir metodología a ojo.
  if (categoria.usaAtr && derivada.fase == null) {
    return BorradorDePeticion(
      fase: derivada,
      resultado: null,
      faltaLaFase: true,
    );
  }

  final paraElMotor = PeticionGeneracion(
    // De la ficha: es del entrenador, no del nadador.
    categoria: categoria,
    // Del nadador: lo confirmó o lo cambió para esta petición.
    estiloObjetivo: respuestas.estiloObjetivo,
    pruebaObjetivo: respuestas.pruebaObjetivo,
    // Derivados.
    faseAtr: derivada.fase,
    componenteAcentuado: componenteParaFase(
      fase: derivada.fase,
      categoria: categoria,
    ),
    // Del nadador.
    diasDisponibles: respuestas.diasDisponibles,
    longitudPiscina: respuestas.longitudPiscina,
    duracionSesionMinutos: respuestas.duracionSesionMinutos,
    // De la ficha. Si está vacío se aplica la progresión estándar y **no se
    // inventan errores** (sección 7 del prompt maestro).
    diagnosticoTecnico: ficha.diagnosticoTecnico,
    nadadoresIds: [peticion.nadadorId],
  );

  final resultado = Generador(
    biblioteca: biblioteca,
    indice: indice,
  ).generar(paraElMotor);

  return BorradorDePeticion(
    fase: derivada,
    resultado: switch (resultado) {
      MicrocicloGenerado(plan: final plan) => MicrocicloGenerado(
        // Marcado con de qué petición salió y bajo qué metodología. El origen
        // ya lo pone el motor: `automatico`, el mismo que cualquier otro plan
        // generado. *De qué petición* es otra pregunta (decisión D5).
        plan: plan.copiarCon(
          peticionId: peticion.nadadorId,
          versionMetodologia: versionMetodologia,
        ),
        supuestos: resultado.supuestos,
        vaciosDeBiblioteca: resultado.vaciosDeBiblioteca,
        avisos: resultado.avisos,
      ),
      _ => resultado,
    },
    faltaLaFase: false,
  );
}
