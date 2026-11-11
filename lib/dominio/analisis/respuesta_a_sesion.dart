/// Una sesión y lo que el nadador dijo de ella, **lado a lado y sin juntarse**.
///
/// Es el principio VIII convertido en tipo. La carga externa —metros, series,
/// zonas— vive en la [Sesion]; la interna —si la hizo, el esfuerzo percibido,
/// lo que anotó, la molestia— vive en el [RegistroDeSesion]. Están en campos
/// distintos porque el principio VIII prohíbe combinarlas en un mismo
/// indicador, y tenerlas separadas hace que combinarlas no sea un descuido
/// posible: habría que escribir un miembro nuevo a propósito.
///
/// **Aquí no hay ningún miembro que mire a los dos a la vez**, y eso lo vigila
/// `test/dominio/analisis/las_dos_cargas_no_se_juntan_test.dart` leyendo esta
/// fuente. Lo que pide la decisión D8 no es que nadie multiplique metros por
/// RPE hoy: es que el día que alguien quiera hacerlo tenga que romper un
/// cerrojo con su nombre.
///
/// Dominio puro: ni Flutter ni Firebase (principio II).
library;

import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';

class RespuestaASesion {
  const RespuestaASesion({required this.sesion, this.registro, this.peticion});

  /// Lo programado. Carga **externa**.
  final Sesion sesion;

  /// Lo que el nadador contestó. Carga **interna**.
  ///
  /// **Nulo cuando no contestó**, y eso no es un error: un hueco y un «no la
  /// hice» dicen cosas distintas, y mezclarlos le enseñaría al entrenador una
  /// respuesta donde hay una ausencia. La diferencia la lee
  /// `ProgresoEnElMacrociclo` desde la feature 009 y aquí se conserva.
  final RegistroDeSesion? registro;

  /// Lo que pidió que mirara de esta sesión, si pidió algo (US4).
  ///
  /// Nula cuando no preguntó nada, que es el caso normal: preguntar es la
  /// excepción, no el formulario.
  final PeticionDeFeedback? peticion;

  /// Si el nadador dijo algo de esta sesión, cualquier cosa.
  bool get fueContestada => registro != null;

  /// Si contestó diciendo que **no** la hizo. No es lo mismo que no contestar.
  bool get dijoQueNo => registro != null && !registro!.realizada;

  /// Si lo que contestó incluye un reporte de dolor, lesión o malestar.
  bool get tieneMolestia => registro?.tieneMolestia ?? false;

  /// Si preguntó algo de esta sesión y su entrenador todavía no la ha visto.
  bool get esperaQueLaMire => peticion != null && peticion!.vistaEn == null;
}
