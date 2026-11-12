/// Las peticiones de feedback, en el dispositivo.
///
/// **Local primero.** `guardar` escribe aquí y no mira la red: es la garantía
/// G1 del contrato de sincronización, la misma que `RegistrosLocales` sostiene
/// para los registros, y es lo que hace que preguntar a pie de piscina no
/// pueda fallar por falta de señal.
///
/// `marcarVista` **no existe aquí**, y no es un olvido: el `vistaEn` lo
/// escribe el entrenador en el servidor y el teléfono de la nadadora no tiene
/// nada que decir al respecto. Llamarlo lanza, en lugar de guardar en silencio
/// una marca que nadie puso.
library;

import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

const String _coleccion = 'peticionesDeFeedback';

class PeticionesFeedbackLocales implements RepositorioPeticionesDeFeedback {
  const PeticionesFeedbackLocales(this.almacen);

  final AlmacenLocal almacen;

  @override
  Future<List<PeticionDeFeedback>> deNadador(String nadadorId) async {
    final todas = await almacen.leerTodo(_coleccion);
    return todas.values
        .map(peticionDeFeedbackDesdeJson)
        .where((p) => p.nadadorId == nadadorId)
        .toList();
  }

  @override
  Future<List<PeticionDeFeedback>> deNadadorEnPlan(
    String nadadorId,
    String planId,
  ) async {
    final todas = await almacen.leerTodo(_coleccion);
    // Los dos filtros, igual que la consulta del servidor: así el doble local
    // y el remoto responden a la misma pregunta.
    return todas.values
        .map(peticionDeFeedbackDesdeJson)
        .where((p) => p.nadadorId == nadadorId && p.planId == planId)
        .toList();
  }

  @override
  Future<void> guardar(PeticionDeFeedback peticion) async {
    // Un fallo aquí **sí** se propaga (garantía S8): si el dispositivo rechaza
    // la escritura, la pregunta se perdería, y eso la nadadora tiene que
    // saberlo.
    await almacen.escribir(
      _coleccion,
      peticion.id,
      peticionDeFeedbackAJson(peticion),
    );
  }

  @override
  Future<void> marcarVista(String peticionId, DateTime cuando) async =>
      throw const FalloDeDatos(
        'El «la vi» lo escribe el entrenador en el servidor, no este '
        'dispositivo',
      );
}
