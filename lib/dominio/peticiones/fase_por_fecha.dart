/// La fase ATR, derivada de la fecha de la competencia.
///
/// **Es la única regla de entrenamiento nueva de la feature 008**, y hace algo
/// delicado: decide metodología sin que el entrenador esté delante. Por eso no
/// devuelve una fase a secas, sino una fase **con su razón escrita**, que viaja
/// hasta el borrador y que el entrenador puede cambiar de un toque. Una fase
/// derivada que no se puede ver ni corregir sería criterio delegado por la
/// puerta de atrás, y el principio IV dice que el criterio no se delega.
///
/// Las fronteras no están elegidas a mano: salen de las duraciones de bloque
/// que la sección 12 de `PROMPT_MAESTRO_V3.4` cita (Issurin 2010), tomando el
/// **límite superior** de cada ventana publicada.
///
/// Por qué el superior: con el inferior, un nadador a diez días de competir
/// caería en Transformación, **dentro de la ventana de afinación publicada**.
/// Ese es el error que cuesta una competencia. Con el superior, solo cae en la
/// fase anterior —más general— quien ya está fuera de toda ventana publicada
/// de la siguiente. Confirmado por el entrenador (T065).
library;

import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

/// Último día de la ventana de Realización. Issurin: 8-15 días.
const int ultimoDiaDeRealizacion = 15;

/// Último día de la ventana de Transformación, contado desde la competencia:
/// los 15 de Realización más las 4 semanas de su propia ventana (2-4).
const int ultimoDiaDeTransformacion = ultimoDiaDeRealizacion + 28;

/// Una fase derivada, con lo que hace falta para poder discutirla.
class FaseDerivada {
  const FaseDerivada({
    required this.fase,
    required this.diasHastaLaCompetencia,
    required this.porQue,
  });

  /// Nula cuando la categoría no usa ATR, o cuando no hay fecha utilizable.
  /// **El motor prohíbe la fase en el primer caso**, así que aquí nula no es
  /// un hueco: es la respuesta correcta.
  final FaseAtr? fase;

  /// Nulos cuando no hay fecha utilizable.
  final int? diasHastaLaCompetencia;

  /// Siempre presente y siempre legible. Es lo que el entrenador lee antes de
  /// aceptar o cambiar la fase, así que no puede venir vacía ni en jerga.
  final String porQue;

  bool get hayFase => fase != null;
}

/// Deriva la fase. **Función total**: para cualquier fecha y cualquier
/// categoría hay respuesta, y «sin fase» es una respuesta.
FaseDerivada faseParaCompetencia({
  required DateTime? fechaDeCompetencia,
  required DateTime hoy,
  required Categoria categoria,
}) {
  if (!categoria.usaAtr) {
    // No es que falte el dato: es que el motor rechaza una fase aquí. Decirlo
    // así evita que alguien lo lea como un hueco por rellenar.
    return FaseDerivada(
      fase: null,
      diasHastaLaCompetencia: null,
      porQue:
          'Sin fase: ${categoria.nombre} no trabaja por fases ATR, así que el '
          'plan no lleva ninguna.',
    );
  }

  if (fechaDeCompetencia == null) {
    return const FaseDerivada(
      fase: null,
      diasHastaLaCompetencia: null,
      porQue:
          'Sin fase: no hay fecha de competencia. La pone el entrenador antes '
          'de generar.',
    );
  }

  final dias = _diasEnteros(desde: hoy, hasta: fechaDeCompetencia);

  if (dias <= 0) {
    // Una competencia que ya pasó no es una fecha. Derivar Realización de ella
    // sería rellenar un hueco con una suposición (regla R3).
    return FaseDerivada(
      fase: null,
      diasHastaLaCompetencia: null,
      porQue: dias == 0
          ? 'Sin fase: la competencia es hoy, y de hoy no se deriva una fase.'
          : 'Sin fase: esa competencia ya pasó. La fecha o la fase las pone el '
                'entrenador.',
    );
  }

  final fase = dias <= ultimoDiaDeRealizacion
      ? FaseAtr.realizacion
      : dias <= ultimoDiaDeTransformacion
      ? FaseAtr.transformacion
      : FaseAtr.acumulacion;

  return FaseDerivada(
    fase: fase,
    diasHastaLaCompetencia: dias,
    porQue:
        '${fase.nombre}, porque la competencia es en $dias '
        '${dias == 1 ? 'día' : 'días'}.',
  );
}

/// Días enteros entre dos fechas, **por fecha y no por horas transcurridas**.
///
/// Sin esto, una competencia a las 23:59 y otra a las 00:01 del mismo día
/// caerían en fases distintas justo en la frontera, y la fase dependería de la
/// hora a la que alguien abrió la app.
int _diasEnteros({required DateTime desde, required DateTime hasta}) {
  final a = DateTime(desde.year, desde.month, desde.day);
  final b = DateTime(hasta.year, hasta.month, hasta.day);
  return b.difference(a).inDays;
}
