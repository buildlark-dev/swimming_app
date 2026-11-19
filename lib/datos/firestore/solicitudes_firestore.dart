/// Las solicitudes de ingreso sobre Firestore (feature 012).
///
/// Identificador determinista, `nadadorId|comunidadId`: pedir dos veces es
/// pedir lo mismo, y un reintento sin señal no puede crear dos solicitudes. Es
/// la misma forma que la feature 010 usó para las peticiones de feedback.
///
/// **Resolverlas no está aquí.** Aceptar escribe además la pertenencia, y las
/// dos cosas tienen que pasar juntas o ninguna, así que eso es un acto del
/// servidor (research D4). Lo que vive aquí es pedir, retirar y leer.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/firestore/lo_que_haya.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/comunidad/solicitud_de_ingreso.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

const String coleccionSolicitudes = 'solicitudesDeIngreso';

class RepositorioSolicitudesFirestore implements RepositorioSolicitudes {
  RepositorioSolicitudesFirestore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _solicitudes =>
      _db.collection(coleccionSolicitudes);

  @override
  Future<SolicitudDeIngreso?> laMia(String nadadorId) async {
    try {
      // **Filtrada por `nadadorId`**, que es lo que la regla deja demostrar:
      // una consulta se demuestra por sus filtros, no documento a documento.
      final instantanea = await _solicitudes
          .where('nadadorId', isEqualTo: nadadorId)
          .leerLoQueHaya();

      SolicitudDeIngreso? laUltima;
      for (final documento in instantanea.docs) {
        final leida = _desde(documento.data());
        if (leida == null) continue;
        // La que espera manda; si no hay ninguna esperando, la más reciente,
        // que es la que explica por qué no pertenece a nada.
        if (leida.estado.estaEsperando) return leida;
        if (laUltima == null || leida.pedidaEn.isAfter(laUltima.pedidaEn)) {
          laUltima = leida;
        }
      }
      return laUltima;
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo leer tu solicitud: ${e.message}');
    }
  }

  @override
  Future<List<SolicitudDeIngreso>> lasQueEsperanEn(String comunidadId) async {
    try {
      // **Los dos filtros, y el segundo no es un adorno.** La regla deja al
      // entrenador leer las de su comunidad; sin el filtro de comunidad no se
      // puede demostrar y la consulta se rechaza entera. Es exactamente el
      // defecto que la feature 009 encontró con los macrociclos.
      final instantanea = await _solicitudes
          .where('comunidadId', isEqualTo: comunidadId)
          .where('estado', isEqualTo: EstadoDeSolicitud.esperando.clave)
          .leerLoQueHaya();

      final leidas = <SolicitudDeIngreso>[];
      for (final documento in instantanea.docs) {
        final leida = _desde(documento.data());
        if (leida != null) leidas.add(leida);
      }

      leidas.sort((a, b) => a.pedidaEn.compareTo(b.pedidaEn));
      return List.unmodifiable(leidas);
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudieron leer las solicitudes: ${e.message}');
    }
  }

  @override
  Future<void> pedir(SolicitudDeIngreso solicitud) async {
    try {
      // **Si había otra esperando, se retira primero** (FR-008). Una nadadora
      // tiene como mucho una solicitud esperando: pedir en otro sitio es
      // cambiar de idea, no pedir dos veces.
      final anterior = await laMia(solicitud.nadadorId);
      if (anterior != null &&
          anterior.estado.estaEsperando &&
          anterior.comunidadId != solicitud.comunidadId) {
        await retirar(anterior.nadadorId, anterior.comunidadId);
      }

      await _solicitudes.doc(solicitud.id).set({
        'nadadorId': solicitud.nadadorId,
        'comunidadId': solicitud.comunidadId,
        'estado': solicitud.estado.clave,
        'pedidaEn': solicitud.pedidaEn.toIso8601String(),
      });
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo pedir el ingreso: ${e.message}');
    }
  }

  @override
  Future<void> retirar(String nadadorId, String comunidadId) async {
    try {
      // **Solo el estado y la fecha.** La regla no deja tocar nada más, y
      // mandar el documento entero sería pedirle permiso para lo que no se
      // necesita — el error que la feature 009 cometió al entregar un plan.
      await _solicitudes.doc('$nadadorId|$comunidadId').update({
        'estado': EstadoDeSolicitud.retirada.clave,
        'resueltaEn': DateTime.now().toIso8601String(),
      });
    } on FirebaseException catch (e) {
      throw FalloDeDatos('No se pudo retirar la solicitud: ${e.message}');
    }
  }

  SolicitudDeIngreso? _desde(Map<String, dynamic> datos) {
    final nadadorId = datos['nadadorId'] as String?;
    final comunidadId = datos['comunidadId'] as String?;
    final pedidaEn = fechaDeJson(datos['pedidaEn']);
    if (nadadorId == null || comunidadId == null || pedidaEn == null) {
      return null;
    }

    return SolicitudDeIngreso(
      nadadorId: nadadorId,
      comunidadId: comunidadId,
      pedidaEn: pedidaEn,
      estado:
          EstadoDeSolicitud.porClave(datos['estado'] as String?) ??
          EstadoDeSolicitud.esperando,
      resueltaEn: fechaDeJson(datos['resueltaEn']),
    );
  }
}
