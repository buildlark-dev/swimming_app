/// Las peticiones de feedback, en el servidor.
///
/// **Dos filtros en `deNadadorEnPlan`, y el segundo no es decoración.** Una
/// consulta de Firestore se demuestra contra las reglas **por sus filtros**:
/// el servidor no mira los documentos que volverían, mira si la consulta
/// puede probar que solo pide lo permitido. Una consulta que no diga «de este
/// nadador» se rechaza entera, no se recorta.
///
/// Es el defecto `75a765f` de la feature 009, encontrado en el Pixel 7: la
/// consulta de macrociclos le faltaba el filtro de estado, el servidor la
/// negaba completa, y la pantalla de la nadadora salía con «The caller does
/// not have permission». En memoria no se notaba, porque el doble no tiene
/// reglas que romper.
///
/// `guardar` escribe aquí **sin esperar**: quien llama es la bandeja de
/// salida, que ya escribió en el dispositivo primero (garantía G1). Esta clase
/// no es el camino del nadador al servidor, es el último tramo de él.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/firestore/lo_que_haya.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// El nombre de la colección. **No es `peticionesDePlan`.**
///
/// Son dos cosas distintas y la feature 008 ya dejó escrito por qué el nombre
/// importa: dos colecciones parecidas en la misma base es como se escribe una
/// regla contra la equivocada, y aquí hay datos de un menor.
const String coleccionPeticionesDeFeedback = 'peticionesDeFeedback';

class PeticionesFeedbackFirestore implements RepositorioPeticionesDeFeedback {
  const PeticionesFeedbackFirestore(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _peticiones =>
      firestore.collection(coleccionPeticionesDeFeedback);

  @override
  Future<List<PeticionDeFeedback>> deNadador(String nadadorId) async {
    try {
      final instantanea = await _peticiones
          .where('nadadorId', isEqualTo: nadadorId)
          .leerLoQueHaya();

      return instantanea.docs
          .map((d) => peticionDeFeedbackDesdeJson(d.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudieron leer las peticiones: ${e.message}');
    }
  }

  @override
  Future<List<PeticionDeFeedback>> deNadadorEnPlan(
    String nadadorId,
    String planId,
  ) async {
    try {
      final instantanea = await _peticiones
          .where('nadadorId', isEqualTo: nadadorId)
          .where('planId', isEqualTo: planId)
          .leerLoQueHaya();

      return instantanea.docs
          .map((d) => peticionDeFeedbackDesdeJson(d.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudieron leer las peticiones: ${e.message}');
    }
  }

  @override
  Future<void> guardar(PeticionDeFeedback peticion) async {
    try {
      // `set` sobre un identificador determinista: reenviar reescribe el mismo
      // documento en lugar de crear uno nuevo.
      await _peticiones.doc(peticion.id).set(peticionDeFeedbackAJson(peticion));
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo enviar la petición: ${e.message}');
    }
  }

  @override
  Future<void> marcarVista(String peticionId, DateTime cuando) async {
    try {
      // **Un campo y ninguno más.** La regla acepta esta escritura solo
      // cuando el diff afecta a `vistaEn` y a nada más, que es la misma forma
      // que la feature 009 usó para entregar un plan. Un `set` reescribiría el
      // documento entero —incluida la pregunta del nadador— y el servidor lo
      // rechazaría con «The caller does not have permission».
      await _peticiones.doc(peticionId).update({
        'vistaEn': cuando.toIso8601String(),
      });
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo marcar como vista: ${e.message}');
    }
  }
}
