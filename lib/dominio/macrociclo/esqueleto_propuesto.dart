/// El esqueleto temporal del macrociclo, propuesto por la app.
///
/// **Es la única regla de entrenamiento nueva de la feature 009**, y hace algo
/// delicado: decide cuántos bloques tiene una temporada y qué fase es cada
/// uno, sin que el entrenador esté delante. Por eso no devuelve bloques a
/// secas: devuelve bloques **con su razón escrita**, editables antes de
/// confirmar, y los avisos de lo que se sale de lo publicado.
///
/// Es el mismo listón que `faseParaCompetencia` puso en la feature 008, y por
/// el mismo motivo: una propuesta que no se puede ver ni corregir no es una
/// propuesta, es una decisión (M3, FR-005).
///
/// **El reparto entre la app y el entrenador va donde la metodología lo
/// parte.** Esto es aritmética sobre las duraciones de bloque que cita la
/// sección 12: cuántas semanas, en qué orden, contadas hacia atrás. Lo que no
/// está aquí es el modelo de la prueba y el modelo del nadador —pasos 2 y 3 de
/// la sección 4—, que son suyos y que ninguna fórmula deriva (FR-007).
///
/// **Hacia atrás desde la competencia.** Realización al final, Transformación
/// antes, Acumulación rellenando lo que quede. Es el orden en que el modelo
/// está definido, y la posición del taper es la menos negociable de las tres.
/// Contado hacia delante desde hoy, la fecha de competir sería una
/// consecuencia de la longitud del plan en lugar de su ancla.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';

/// Lo mínimo que se considera un bloque, en días.
///
/// Un resto de menos de una semana no se queda como bloque suelto: una
/// etiqueta de fase puesta sobre cuatro días es una etiqueta puesta sobre
/// nada, y el motor repartiría volumen de una fase entera en media semana. Se
/// absorbe en el bloque vecino y la razón lo dice.
const int diasMinimosDeUnBloque = 7;

/// Un esqueleto propuesto, con lo que hace falta para poder discutirlo.
class EsqueletoPropuesto {
  const EsqueletoPropuesto({
    required this.bloques,
    required this.porQue,
    required this.avisos,
    required this.diasHastaLaCompetencia,
  });

  /// Los bloques, del primero al último. Vacío cuando no hay esqueleto que
  /// proponer, que es una respuesta y no un fallo.
  ///
  /// Son `BloqueConfirmado` aunque todavía no estén confirmados: el tipo es el
  /// mismo antes y después, y lo que los confirma es entrar en una
  /// `EstructuraConfirmada` con la firma del entrenador. Tener dos tipos
  /// idénticos para el antes y el después solo añadiría una conversión donde
  /// no hay ninguna diferencia de datos.
  final List<BloqueConfirmado> bloques;

  /// Siempre presente y siempre legible. Es lo que el entrenador lee antes de
  /// aceptar o cambiar el esqueleto, así que no puede venir vacía ni en jerga.
  final String porQue;

  /// Bloques cuya duración se sale de la ventana publicada de su fase, dichos
  /// con la fuente a la vista. **Avisan, nunca suspenden** (M5, FR-012): la
  /// sección 12 anota que la natación usa fases más largas que la literatura
  /// general, y la app no sabe más que el entrenador.
  final List<String> avisos;

  /// Nulos cuando no hay fecha utilizable.
  final int? diasHastaLaCompetencia;

  bool get hayEsqueleto => bloques.isNotEmpty;
}

/// Días enteros entre dos fechas, **por fecha y no por horas transcurridas**.
///
/// Sin esto, dos competencias del mismo día a horas distintas darían
/// estructuras distintas, y la temporada dependería de la hora a la que
/// alguien abrió la app.
int _diasEnteros({required DateTime desde, required DateTime hasta}) {
  final a = DateTime(desde.year, desde.month, desde.day);
  final b = DateTime(hasta.year, hasta.month, hasta.day);
  return b.difference(a).inDays;
}

DateTime _soloLaFecha(DateTime momento) =>
    DateTime(momento.year, momento.month, momento.day);

/// Tope de la ventana publicada de la fase, en días.
int _topeEnDias(FaseAtr fase) {
  final (_, semanas) = fase.semanasSegunIssurin;
  return semanas * 7;
}

String _enSemanas(int dias) {
  final semanas = (dias / 7).ceil();
  return '$semanas ${semanas == 1 ? 'semana' : 'semanas'}';
}

/// Propone el esqueleto. **Función total**: para cualquier fecha y cualquier
/// categoría hay respuesta, y «sin esqueleto» es una respuesta.
EsqueletoPropuesto esqueletoParaMacrociclo({
  required DateTime? fechaDeCompetencia,
  required DateTime hoy,
  required Categoria categoria,
}) {
  if (fechaDeCompetencia == null) {
    return const EsqueletoPropuesto(
      bloques: [],
      porQue:
          'Sin estructura: no hay fecha de competencia. El macrociclo se '
          'cuenta hacia atrás desde ella, así que es lo primero.',
      avisos: [],
      diasHastaLaCompetencia: null,
    );
  }

  final dias = _diasEnteros(desde: hoy, hasta: fechaDeCompetencia);

  if (dias <= 1) {
    // Una competencia que ya pasó no es un ancla. Derivar una estructura de
    // ella sería rellenar un hueco con una suposición (regla R3).
    //
    // **Y mañana tampoco.** Como el día de competir no se entrena, una
    // competencia mañana deja un solo día de preparación, y un bloque de un
    // día no es un bloque: la invariante de `BloqueConfirmado` lo rechaza y
    // tiene razón. Antes salía un bloque de dos días porque el día de la
    // carrera contaba como entrenamiento.
    return EsqueletoPropuesto(
      bloques: const [],
      porQue: switch (dias) {
        1 =>
          'Sin estructura: la competencia es mañana, y un día no da para '
              'una preparación.',
        0 =>
          'Sin estructura: la competencia es hoy, y de hoy no sale una '
              'preparación.',
        _ =>
          'Sin estructura: esa competencia ya pasó. La fecha la pone el '
              'entrenador.',
      },
      avisos: const [],
      diasHastaLaCompetencia: null,
    );
  }

  final competencia = _soloLaFecha(fechaDeCompetencia);
  final primerDia = _soloLaFecha(hoy);

  /// **La preparación termina la víspera.** El día de la competencia no se
  /// entrena: se compite. Lo pidió el entrenador tras ver en el recorrido que
  /// el camino de la nadadora acababa en «Viernes 1/1» y el 1/1 era la
  /// carrera.
  ///
  /// Se corrige aquí, donde se reparten los bloques, y no quitando ese día
  /// más abajo: sacarlo después dejaba la última semana con dos días de
  /// piscina en lugar de tres, y el motor la rechaza con razón, porque la
  /// frecuencia de la categoría es una regla de la metodología. Lo que cambia
  /// es que hay un día menos de preparación, que es la verdad.
  final vispera = competencia.subtract(const Duration(days: 1));

  // Desde hoy hasta la víspera, los dos incluidos.
  final total = dias;

  if (!categoria.usaAtr) {
    // M6. Aquí la fase nula no es un hueco por rellenar: el motor la prohíbe
    // en estas categorías, y decirlo evita que alguien lo lea como algo que
    // falta por poner.
    return EsqueletoPropuesto(
      bloques: [
        BloqueConfirmado(
          fase: null,
          desde: primerDia,
          hasta: vispera,
          porQue:
              'Sin fase: ${categoria.nombre} no trabaja por fases ATR, así '
              'que el macrociclo va de una pieza, ${_enSemanas(total)} hasta '
              'la competencia.',
        ),
      ],
      porQue:
          '${_enSemanas(total)} hasta la competencia. ${categoria.nombre} no '
          'trabaja por fases ATR, así que no se reparte en bloques.',
      // No se compara con las ventanas de Issurin: medir un bloque sin fase
      // con la regla de otra categoría no diría nada.
      avisos: const [],
      diasHastaLaCompetencia: dias,
    );
  }

  // Hacia atrás: primero el taper, que es lo que no se mueve.
  var diasDeRealizacion = _topeEnDias(FaseAtr.realizacion);
  if (diasDeRealizacion > total) diasDeRealizacion = total;

  var resto = total - diasDeRealizacion;
  if (resto > 0 && resto < diasMinimosDeUnBloque) {
    diasDeRealizacion += resto;
    resto = 0;
  }

  var diasDeTransformacion = resto == 0
      ? 0
      : (resto < _topeEnDias(FaseAtr.transformacion)
            ? resto
            : _topeEnDias(FaseAtr.transformacion));

  var diasDeAcumulacion = resto - diasDeTransformacion;
  if (diasDeAcumulacion > 0 && diasDeAcumulacion < diasMinimosDeUnBloque) {
    diasDeTransformacion += diasDeAcumulacion;
    diasDeAcumulacion = 0;
  }

  final bloques = <BloqueConfirmado>[];
  final avisos = <String>[];

  // Se construyen de atrás hacia delante y se devuelven en orden.
  final realizacionDesde = vispera.subtract(
    Duration(days: diasDeRealizacion - 1),
  );
  final realizacion = BloqueConfirmado(
    fase: FaseAtr.realizacion,
    desde: realizacionDesde,
    hasta: vispera,
    porQue:
        'Realización, las últimas ${_enSemanas(diasDeRealizacion)} antes de '
        'la competencia: es la afinación, y por eso va pegada a ella.',
  );

  BloqueConfirmado? transformacion;
  if (diasDeTransformacion > 0) {
    final hasta = realizacionDesde.subtract(const Duration(days: 1));
    transformacion = BloqueConfirmado(
      fase: FaseAtr.transformacion,
      desde: hasta.subtract(Duration(days: diasDeTransformacion - 1)),
      hasta: hasta,
      porQue:
          'Transformación, ${_enSemanas(diasDeTransformacion)} antes del '
          'taper: umbral y ritmo de competencia.',
    );
  }

  BloqueConfirmado? acumulacion;
  if (diasDeAcumulacion > 0) {
    final hasta = (transformacion ?? realizacion).desde.subtract(
      const Duration(days: 1),
    );
    acumulacion = BloqueConfirmado(
      fase: FaseAtr.acumulacion,
      desde: primerDia,
      hasta: hasta,
      porQue:
          'Acumulación, las primeras ${_enSemanas(diasDeAcumulacion)}: es la '
          'base, y se queda con lo que no es transformación ni afinación.',
    );
  }

  if (acumulacion != null) bloques.add(acumulacion);
  if (transformacion != null) bloques.add(transformacion);
  bloques.add(realizacion);

  for (final bloque in bloques) {
    if (bloque.cabeEnLaVentanaPublicada) continue;
    final (minimo, maximo) = bloque.fase!.semanasSegunIssurin;
    avisos.add(
      '${bloque.fase!.nombre} de ${_enSemanas(bloque.hasta.difference(bloque.desde).inDays + 1)}: '
      'Issurin (2010) publica $minimo a $maximo. La sección 12 anota que la '
      'natación usa fases más largas que la literatura general, y el '
      'macrociclo real de referencia tiene 14 semanas con 2 de afinación. '
      'Se avisa y decide usted.',
    );
  }

  return EsqueletoPropuesto(
    bloques: List.unmodifiable(bloques),
    porQue:
        '${_enSemanas(total)} hasta la competencia, repartidas hacia atrás '
        'desde ella en ${bloques.length} '
        '${bloques.length == 1 ? 'bloque' : 'bloques'}.',
    avisos: List.unmodifiable(avisos),
    diasHastaLaCompetencia: dias,
  );
}

/// Un bloque tal como el entrenador lo deja: su fase y cuántas semanas dura.
typedef BloqueEditado = ({FaseAtr? fase, int semanas});

/// Recompone el esqueleto con lo que el entrenador cambió (M3, FR-005).
///
/// **Sin esto, «editable» sería una palabra.** Los bloques son contiguos y van
/// contados hacia atrás desde la competencia, así que cambiar la duración de
/// uno mueve los demás: no se puede editar un bloque suelto sin recolocar la
/// cadena. Esta función es la que hace que cambiar el número de bloques, sus
/// fases o sus semanas produzca una estructura válida en lugar de una con
/// huecos.
///
/// Lo que decide él y lo que sale de aquí: él pone fases y semanas, y de ahí
/// salen las fechas. El día de la competencia no se mueve nunca —es el ancla—,
/// así que **alargar la preparación la hace empezar antes**, no acabar después.
/// Es lo correcto: lo que él está decidiendo es cuánto dura la preparación.
///
/// La razón de cada bloque dice que la puso él. Un `porQue` que siguiera
/// diciendo «las últimas 2 semanas antes de la competencia» cuando él las
/// cambió a cuatro sería la app atribuyéndose una decisión suya.
List<BloqueConfirmado> recomponerElEsqueleto({
  required List<BloqueEditado> bloques,
  required DateTime fechaDeCompetencia,
}) {
  if (bloques.isEmpty) return const [];

  final competencia = _soloLaFecha(fechaDeCompetencia);
  final recompuestos = <BloqueConfirmado>[];

  // Hacia atrás, igual que la propuesta: el último termina **la víspera**.
  // El día de la competencia no se entrena, también cuando los bloques los
  // pone él a mano.
  var hasta = competencia.subtract(const Duration(days: 1));

  for (final bloque in bloques.reversed) {
    final dias = bloque.semanas * 7;
    final desde = hasta.subtract(Duration(days: dias - 1));

    recompuestos.insert(
      0,
      BloqueConfirmado(
        fase: bloque.fase,
        desde: desde,
        hasta: hasta,
        porQue: bloque.fase == null
            ? 'Sin fase: ${_enSemanas(dias)}, puestas por el entrenador.'
            : '${bloque.fase!.nombre}, ${_enSemanas(dias)}, '
                  'puestas por el entrenador.',
      ),
    );

    hasta = desde.subtract(const Duration(days: 1));
  }

  return recompuestos;
}

/// Lo que falta en la ficha para poder empezar un macrociclo (M7, regla R3).
///
/// **Ante datos faltantes se pregunta, no se supone.** Un esqueleto construido
/// sobre huecos llevaría la firma del entrenador encima de una suposición
/// nuestra.
///
/// Reutiliza `Nadador.faltas` —nombre, categoría y estilo objetivo— y añade la
/// que esta feature necesita: la prueba objetivo. El macrociclo se construye
/// **hacia** una prueba, y sin saber cuál, modelar la prueba es modelar algo
/// sin nombre.
List<FaltaEnPerfil> faltasParaElMacrociclo(Nadador ficha) => <FaltaEnPerfil>[
  ...ficha.faltas,
  if (ficha.pruebaObjetivo.trim().isEmpty)
    const FaltaEnPerfil(
      'pruebaObjetivo',
      'Falta la prueba objetivo: el macrociclo se construye hacia una '
          'prueba, y sin ella no hay nada que modelar',
    ),
];
