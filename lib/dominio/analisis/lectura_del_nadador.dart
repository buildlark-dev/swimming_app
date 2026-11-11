/// Lo que el entrenador necesita de un nadador, reunido para leerlo.
///
/// **Es el paso que faltaba.** La metodología cierra un bucle —diagnosticar,
/// modelar, programar, *controlar*, reajustar— y el producto tenía todos los
/// pasos menos el control: la nadadora contesta desde la feature 003 y sus
/// respuestas se escriben en el servidor desde entonces, y nadie se las leía
/// de vuelta. «Un registro que nadie lee no es control.»
///
/// Esta lectura **no se guarda**. Se arma al mirarla, como
/// `ProgresoEnElMacrociclo`: guardarla crearía una segunda copia de algo que
/// el servidor ya tiene, y se quedaría vieja en cuanto ella volviera a
/// contestar.
///
/// Tres cosas que esto **no** hace, cada una por su motivo:
///
/// 1. **No vuelve a calcular la adherencia.** La calcula
///    `ProgresoEnElMacrociclo` desde la feature 009 y aquí se lee. Un segundo
///    cálculo sería una segunda metodología por la puerta de atrás
///    (principio I), y el cerrojo está en
///    `test/dominio/analisis/la_adherencia_no_se_recalcula_test.dart`.
/// 2. **No junta la carga externa con la interna.** Cada sesión y su respuesta
///    viajan en un `RespuestaASesion`, que no tiene ningún miembro que mire a
///    las dos (principio VIII, decisión D8).
/// 3. **No se come un fallo.** Si los registros no se pueden leer, el fallo
///    sube. Una lectura vacía y una ilegible le dicen cosas opuestas a quien
///    está decidiendo qué programar, y convertir la segunda en la primera es
///    el defecto que la feature 009 entregó dos veces.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/analisis/respuesta_a_sesion.dart';
import 'package:natacion_app/dominio/calculo/progreso_nadador.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/macrociclo/progreso_en_el_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/registros_del_linaje.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class LecturaDelNadador {
  LecturaDelNadador({
    required this.nadador,
    required List<Plan> mesociclos,
    required List<RespuestaASesion> respuestas,
    required this.progreso,
    List<RegistroDeSesion> sinSesion = const [],
  }) : mesociclos = List.unmodifiable(mesociclos),
       respuestas = List.unmodifiable(respuestas),
       sinSesion = List.unmodifiable(sinSesion);

  final Nadador nadador;

  /// Sus mesociclos, en el orden del macrociclo.
  final List<Plan> mesociclos;

  /// Una por sesión programada, **de la más reciente a la más antigua**.
  ///
  /// Hay una por sesión aunque no la haya contestado: la ausencia es parte de
  /// lo que el entrenador lee.
  final List<RespuestaASesion> respuestas;

  /// Lo que contestó sobre sesiones que **no están en su plan**.
  ///
  /// Hallazgo del recorrido en el Pixel 7. Un registro apuntaba a `s-2` y las
  /// sesiones del plan eran `s0`, `s1`, `s2`; la respuesta —con una molestia
  /// dentro— se caía por el camino sin decir nada, mientras la lista del
  /// `Análisis` marcaba a la nadadora, porque esa consulta mira la colección
  /// de registros y no las sesiones. **Dos pantallas de la misma app diciendo
  /// cosas contrarias.**
  ///
  /// Que llegaran así fue culpa de la herramienta de siembra. Que
  /// desaparecieran era culpa de aquí: el principio VIII dice que un reporte
  /// de dolor **llega al entrenador**, y «llega» no admite caerse por el
  /// camino porque su sesión ya no esté.
  ///
  /// **Se enseñan y no se cuentan.** La adherencia cuenta sesiones
  /// programadas, y una sesión que no está en el plan no se programó.
  final List<RegistroDeSesion> sinSesion;

  /// Las huérfanas que además llevan un reporte de dolor. Son las que no se
  /// pueden perder.
  List<RegistroDeSesion> get molestiasSinSesion =>
      sinSesion.where((r) => r.tieneMolestia).toList();

  /// Dónde va, calculado por la feature 009. Aquí solo se lee.
  final ProgresoEnElMacrociclo progreso;

  /// Lo que dijo que le dolía. **Aparte del resto**, que es lo que exige el
  /// principio VIII: un reporte de dolor dentro del flujo de observaciones
  /// solo se encuentra si alguien lee todas las observaciones de todas las
  /// sesiones.
  ///
  /// Es un getter y no un campo a propósito: así no puede discrepar de
  /// `respuestas`.
  List<RespuestaASesion> get conMolestia =>
      respuestas.where((r) => r.tieneMolestia).toList();

  /// Lo que pidió que mirara y él todavía no ha visto (FR-017).
  ///
  /// Es un getter y no un campo para que no pueda discrepar de `respuestas`.
  List<RespuestaASesion> get esperandoQueLasMire =>
      respuestas.where((r) => r.esperaQueLaMire).toList();

  /// Cuántas de las programadas completó, leído de `progreso`.
  Adherencia get adherencia => progreso.adherencia;

  /// Si no dijo nada de ninguna sesión.
  ///
  /// **No es lo mismo que no haberse podido leer**, y por eso esto es una
  /// pregunta sobre una lectura que existe: cuando no se pudo leer no hay
  /// lectura a la que preguntárselo, porque el fallo subió.
  bool get noHaContestadoNada => respuestas.every((r) => !r.fueContestada);

  /// Bajo qué versión de metodología se construyó lo que se está leyendo
  /// (FR-004).
  ///
  /// Sale del plan y no de una constante: una constante diría la versión de
  /// hoy sobre un plan firmado hace tres meses.
  String? get versionMetodologia {
    for (final mesociclo in mesociclos) {
      final version = mesociclo.versionMetodologia;
      if (version != null && version.isNotEmpty) return version;
    }
    return null;
  }
}

/// Arma la lectura de un nadador.
///
/// Los registros se piden **por el linaje de versiones** y no por el plan
/// actual. Un reajuste crea un plan nuevo con identificador nuevo, y los
/// registros apuntan a donde se escribieron: leer solo el plan actual devuelve
/// cero sobre una nadadora que entrenó, pinta la pantalla y no falla. Eso es
/// `b7a5120` de la feature 009, encontrado en el Pixel 7.
Future<LecturaDelNadador> leerAlNadador({
  required Nadador nadador,
  required List<Plan> mesociclos,
  required RepositorioRegistros registros,
  required RepositorioPlanes planes,
  required DateTime hoy,
  RepositorioPeticionesDeFeedback? peticiones,
}) async {
  final nadadorId = nadador.id ?? '';

  final todos = <RegistroDeSesion>[];
  for (final mesociclo in mesociclos) {
    todos.addAll(
      await registrosDelLinaje(
        mesociclo: mesociclo,
        nadadorId: nadadorId,
        registros: registros,
        planes: planes,
      ),
    );
  }

  // Por sesión. `registrosDelLinaje` ya deja uno por sesión y por mesociclo,
  // con la versión más nueva ganando; esto junta los mesociclos.
  final porSesion = <String, RegistroDeSesion>{};
  for (final registro in todos) {
    porSesion.putIfAbsent(registro.sesionId, () => registro);
  }

  // Lo que pidió que mirara, si hay de dónde leerlo.
  //
  // **Una consulta por nadadora y no una por mesociclo**, y no es solo por el
  // coste: una petición apunta a la versión del plan en la que ella estaba
  // cuando preguntó, así que preguntar por los mesociclos de ahora perdería
  // de vista las de antes de un reajuste. Es la misma forma del defecto que
  // `registrosDelLinaje` arregla para los registros, y aquí se esquiva
  // leyendo las suyas de una vez y emparejándolas por identificador de sesión,
  // que es lo que un reajuste conserva.
  final peticionPorSesion = <String, PeticionDeFeedback>{};
  if (peticiones != null) {
    for (final peticion in await peticiones.deNadador(nadadorId)) {
      peticionPorSesion[peticion.sesionId] = peticion;
    }
  }

  final respuestas = <RespuestaASesion>[
    for (final mesociclo in mesociclos)
      for (final sesion in mesociclo.sesiones)
        RespuestaASesion(
          sesion: sesion,
          registro: sesion.id == null ? null : porSesion[sesion.id],
          peticion: sesion.id == null ? null : peticionPorSesion[sesion.id],
        ),
  ];

  // Lo que contestó sobre sesiones que no están en el plan.
  //
  // **No se tiran.** Desaparecían en silencio, y la lista del `Análisis`
  // seguía marcando a la nadadora porque esa consulta mira la colección de
  // registros y no las sesiones: dos pantallas de la misma app diciendo cosas
  // contrarias, con el dato en el servidor. Lo encontró el recorrido.
  final programadas = <String>{
    for (final respuesta in respuestas)
      if (respuesta.sesion.id != null) respuesta.sesion.id!,
  };

  final sinSesion = <RegistroDeSesion>[
    for (final registro in porSesion.values)
      if (!programadas.contains(registro.sesionId)) registro,
  ]..sort((a, b) => b.registradoEn.compareTo(a.registradoEn));

  return LecturaDelNadador(
    nadador: nadador,
    mesociclos: mesociclos,
    respuestas: _deLaMasRecienteALaMasAntigua(respuestas),
    sinSesion: sinSesion,
    progreso: ProgresoEnElMacrociclo(
      mesociclos: mesociclos,
      registros: todos,
      hoy: hoy,
    ),
  );
}

/// De la más reciente a la más antigua, **estable y sobre una copia**.
///
/// Lo que acaba de nadar es lo primero que el entrenador quiere leer. Una
/// sesión sin fecha va al final: existe, pero encabezar la lista con la única
/// que no se sabe cuándo fue sería mentir sobre por dónde se empieza.
///
/// Estable a mano, como `Plan.sesionesDe`: `List.sort` no promete conservar el
/// orden de los empates y el dominio es Dart puro, así que se lleva el índice
/// de entrada y se usa para desempatar.
List<RespuestaASesion> _deLaMasRecienteALaMasAntigua(
  List<RespuestaASesion> respuestas,
) {
  final conIndice = <(int, RespuestaASesion)>[];
  for (var i = 0; i < respuestas.length; i++) {
    conIndice.add((i, respuestas[i]));
  }

  conIndice.sort(
    (a, b) => switch ((a.$2.sesion.fecha, b.$2.sesion.fecha)) {
      (null, null) => a.$1 - b.$1,
      (null, _) => 1,
      (_, null) => -1,
      (final x?, final y?) => x == y ? a.$1 - b.$1 : y.compareTo(x),
    },
  );

  return [for (final (_, respuesta) in conIndice) respuesta];
}
