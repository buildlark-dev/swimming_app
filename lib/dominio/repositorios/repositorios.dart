/// Interfaces que el dominio declara y la capa de datos implementa.
///
/// Contrato: `specs/001-editor-planes-auditoria/contracts/almacenamiento.md`.
///
/// **Ninguna firma menciona tipos de Firestore.** Los errores se expresan como
/// resultados del dominio, no como excepciones de la librería de datos.
library;

import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/entidades/asignacion.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';

/// Fallo al acceder a los datos, expresado en términos del dominio.
class FalloDeDatos implements Exception {
  const FalloDeDatos(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

abstract class RepositorioPlanes {
  Future<Plan?> obtener(String id);

  Future<List<Plan>> listar({Categoria? categoria, EstadoPlan? estado});

  /// Guarda un borrador. Devuelve el identificador asignado.
  Future<String> guardarBorrador(Plan plan);

  /// Guarda un plan ya aprobado, con su instantánea de auditoría.
  Future<void> guardarAprobado(Plan plan, Map<String, dynamic> auditoria);

  /// Mueve un plan firmado a publicado. **Firmar no es entregar.**
  ///
  /// Es su propio método y no un `guardarAprobado` con el estado cambiado,
  /// porque **entregar solo puede tocar el estado**. Lo firmado es inmutable
  /// (FR-025) y la regla de Firestore acepta la entrega únicamente cuando el
  /// diff afecta a `estado` y a nada más.
  ///
  /// Se entregaba con `guardarAprobado`, que reescribe el documento entero
  /// —incluida la instantánea de auditoría— y por tanto cambia más de un
  /// campo. La regla lo rechazaba y entregar fallaba con «The caller does not
  /// have permission to execute the specified operation». Lo encontró el
  /// recorrido C8 de la feature 009; afecta igual a la entrega de la 007.
  Future<void> publicar(String id);

  /// Crea una versión nueva en borrador desde un plan aprobado (FR-025).
  Future<Plan> crearVersionDesde(String idAprobado);

  /// Exporta el plan completo en un formato legible sin la app (FR-031).
  Future<Map<String, dynamic>> exportar(String id);
}

/// Los macrociclos: el nivel de encima del plan (feature 009).
///
/// **No hay `RepositorioMesociclos`.** Un mesociclo es un `Plan`, así que lo
/// guarda y lo versiona `RepositorioPlanes`, con el ciclo de vida y el linaje
/// que ya tiene probados desde la feature 001 (decisión D1).
///
/// Lo que el nadador puede hacer aquí es **leer el suyo**. Un macrociclo es
/// trabajo del entrenador y nada de él es del nadador para cambiarlo, así que
/// esta interfaz no ofrece ninguna escritura que un dispositivo de nadador
/// pueda llamar, y las reglas lo comprueban aparte.
///
/// Contrato: `specs/009-plan-progression/contracts/macrociclo_y_progresion.md`.
abstract class RepositorioMacrociclos {
  Future<Macrociclo?> obtener(String id);

  /// Los de un nadador, del más reciente al más antiguo.
  Future<List<Macrociclo>> deNadador(String nadadorId);

  /// Guarda un borrador. Devuelve el identificador asignado.
  Future<String> guardarBorrador(Macrociclo macrociclo);

  /// Guarda un macrociclo ya firmado, con su instantánea de auditoría.
  ///
  /// La instantánea viaja aquí por la misma razón que en los planes: la
  /// auditoría de la sección 16 es parte de lo que se firmó, no un informe
  /// aparte que se pueda perder.
  Future<void> guardarAprobado(
    Macrociclo macrociclo,
    Map<String, dynamic> auditoria,
  );

  /// Mueve el macrociclo a publicado. **Firmar no es entregar.**
  Future<void> publicar(String id);

  /// Apunta el macrociclo entregado a las versiones nuevas de sus mesociclos y
  /// deja el aviso para el nadador (M31, M32).
  ///
  /// Es **una escritura** por reajuste, por muchos mesociclos que haya movido:
  /// de ahí que el nadador se entere una vez. Y es la única escritura que se
  /// permite sobre un macrociclo entregado, porque el reajuste es un acto del
  /// entrenador sobre lo que ya entregó: no cambia lo que firmó, cambia a qué
  /// versión apunta.
  Future<void> anunciarElReajuste(
    String id, {
    required List<String> mesociclos,
    required ReajusteAnunciado aviso,
  });

  /// Exporta el macrociclo completo en un formato legible sin la app.
  Future<Map<String, dynamic>> exportar(String id);
}

abstract class RepositorioSesiones {
  Future<List<Sesion>> obtenerDePlan(String planId);

  Future<String> guardar(String planId, Sesion sesion);

  Future<void> eliminar(String planId, String sesionId);
}

abstract class RepositorioNadadores {
  Future<Nadador?> obtener(String id);

  Future<List<Nadador>> listar();

  Future<String> guardar(Nadador nadador);

  Future<void> eliminar(String id);

  Future<Map<String, dynamic>> exportar(String id);
}

abstract class RepositorioBiblioteca {
  Future<Biblioteca> cargar();
}

/// A quién se le entregó cada plan (feature 004).
///
/// Las asignaciones viven aparte del plan a propósito: un plan aprobado es
/// inmutable, y las reglas de acceso comprueban el consentimiento de **un**
/// nadador por escritura. Ver `lib/dominio/entidades/asignacion.dart`.
abstract class RepositorioAsignaciones {
  Future<List<Asignacion>> listar();

  Future<List<Asignacion>> deNadador(String nadadorId);

  Future<List<Asignacion>> dePlan(String planId);

  /// Entrega el plan a un nadador.
  ///
  /// El servidor comprueba su consentimiento. Si no lo tiene, esto falla, y
  /// falla a propósito: es la puerta de publicación (FR-013).
  Future<void> asignar(Asignacion asignacion);

  /// Retira un plan a un nadador.
  ///
  /// **No borra sus registros**: lo que el nadador ya envió es suyo.
  Future<void> retirar(String planId, String nadadorId);
}

/// Los registros que el nadador escribe sobre sus sesiones (feature 003).
///
/// `guardar` escribe **primero en local** y encola el envío después. Ese orden
/// es la feature: si escribiera primero en el servidor, un nadador sin red
/// perdería lo escrito, que es justo lo que FR-019 prohíbe.
abstract class RepositorioRegistros {
  Future<RegistroDeSesion?> obtener(String registroId);

  Future<List<RegistroDeSesion>> obtenerDePlan(String nadadorId, String planId);

  /// Guarda en el dispositivo. **No consulta la red y no puede fallar por su
  /// causa** (garantía G1 del contrato de sincronización).
  Future<void> guardar(RegistroDeSesion registro);

  /// Exporta los registros de un nadador en formato legible (FR-024).
  Future<Map<String, dynamic>> exportar(String nadadorId);

  /// Borra todos los registros de un nadador (FR-024, principio V).
  Future<void> eliminarDe(String nadadorId);

  /// Quiénes han respondido algo. **Una consulta, no una por nadador.**
  ///
  /// Entra en la feature 007 para que el resumen del entrenador pueda contar
  /// los planes «en uso» —publicados, asignados, y con algún registro de su
  /// nadador— sin preguntar nadador por nadador (decisión D10).
  Future<Set<String>> nadadoresConRegistros();
}

/// La bandeja de salida: lo que sostiene la promesa de que nada se pierde.
///
/// Contrato completo en
/// `specs/003-consumo-del-nadador/contracts/sincronizacion.md`.
abstract class BandejaDeSalida {
  Future<void> encolar(String registroId);

  Future<List<EnvioPendiente>> pendientes();

  Future<EnvioPendiente?> estadoDe(String registroId);

  Future<void> actualizar(EnvioPendiente envio);
}

/// Si hay red, para saber cuándo reintentar.
///
/// Es una interfaz del dominio para que la bandeja no conozca el mecanismo de
/// detección (principio II).
abstract class EstadoDeRed {
  Future<bool> hayConexion();

  /// Emite cada vez que la conectividad cambia.
  Stream<bool> get cambios;
}

/// Envía un registro a su destino. Lo implementa la capa de datos.
abstract class EnvioDeRegistros {
  /// Devuelve la hora del servidor al aceptar el registro.
  ///
  /// Lanza si no se pudo enviar: la bandeja lo traduce a un reintento.
  Future<DateTime> enviar(RegistroDeSesion registro);
}

/// No se pudo entrar, con un mensaje que se le puede enseñar a alguien.
///
/// Es del dominio y no del proveedor a propósito: la pantalla de acceso no
/// tiene por qué saber qué códigos de error devuelve Firebase.
class FalloDeAcceso implements Exception {
  const FalloDeAcceso(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Quién está usando la app (feature 004).
///
/// El dominio no sabe que existe Firebase: habla de [Cuenta] y de `Rol`. La
/// implementación vive en `lib/datos/auth/sesion_firebase.dart`, que es el
/// único archivo del proyecto que puede importar `firebase_auth`, y la prueba
/// de frontera lo vigila.
///
/// Contrato: `specs/004-cuentas-y-consentimiento/contracts/cuentas_y_roles.md`.
abstract class Identidad {
  /// En qué punto está la identidad: sin sesión, con cuenta lista, o con
  /// sesión pero sin rol asignado todavía.
  Future<EstadoDeCuenta> actual();

  /// Entra con una cuenta que ya existe.
  ///
  /// Lanza [FalloDeAcceso] con un mensaje que se le puede enseñar a alguien.
  Future<void> entrar({required String correo, required String clave});

  /// Crea una cuenta. **Nace siempre como nadador** (garantía A2): el rol de
  /// entrenador no se concede por registrarse.
  Future<void> crearCuenta({required String correo, required String clave});

  /// Emite cada vez que la sesión cambia: entra, sale o caduca.
  Stream<EstadoDeCuenta> get cambios;

  /// Cierra la sesión y **no deja en el dispositivo datos del nadador
  /// anterior** (garantía A7): ni la caché de lectura ni lo guardado en local.
  ///
  /// No es una cortesía. El grupo son hermanos que comparten teléfono.
  Future<void> cerrarSesion();

  /// Pide por correo el cambio de contraseña de quien está dentro.
  ///
  /// **Por correo y no en una pantalla** (decisión D9, garantía H30). Un
  /// formulario que pide la contraseña nueva sin comprobar quién la escribe
  /// deja que cualquiera con el teléfono desbloqueado se quede con la cuenta, y
  /// el teléfono lo comparten hermanos. El correo ya está verificado desde el
  /// alta.
  Future<void> pedirCambioDeClave();
}

/// Las peticiones de plan de los nadadores (feature 008).
///
/// **El nadador solo manda; el estado lo escribe el servidor.** Por eso aquí
/// no hay un `guardar` general: hay `enviar`, que es lo único que un
/// dispositivo de nadador puede hacer, y `cerrar`, que pasa por el servidor.
/// Un cliente que pudiera escribir su propio estado podría aprobarse su propia
/// petición.
///
/// Contrato: `specs/008-swimmer-request/contracts/peticion_de_plan.md`.
abstract class RepositorioPeticiones {
  /// La petición abierta de este nadador, si tiene una. Nula si no.
  Future<PeticionDePlan?> miPeticion(String nadadorId);

  /// Lo que le llegó al entrenador. Lectura: la cola no se escribe mirándola.
  Future<List<PeticionDePlan>> cola();

  /// Manda una petición nueva. Falla si ya hay una abierta de ese nadador, y
  /// **lo comprueban las reglas**, no esta implementación.
  Future<void> enviar({
    required String nadadorId,
    required RespuestasDePeticion respuestas,
  });

  /// El entrenador la abre: pasa a `enRevision`. Lo mueve él y nadie más.
  Future<void> marcarEnRevision(String nadadorId);
}
