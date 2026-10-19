/// Identidad contra Firebase Authentication.
///
/// **Este es el único archivo del proyecto que puede importar
/// `firebase_auth`**, y la prueba de frontera de `test/dominio/arquitectura_test.dart`
/// lo comprueba. El resto de la app —dominio e interfaz— habla de [Cuenta] y de
/// [Rol], que son tipos del dominio.
///
/// No es purismo: es que cambiar de proveedor de identidad tiene que ser un
/// archivo, no una búsqueda por todo el repositorio.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Cómo se lee el rol dentro del token.
///
/// Tiene que coincidir con lo que leen las reglas de acceso:
/// `request.auth.token.rol`. Si cambia aquí, cambia en `firestore.rules` el
/// mismo día, y las pruebas de reglas se enteran.
const String claveDelRol = 'rol';

/// Dónde vive el vínculo entre la cuenta y el perfil de nadador.
///
/// El rol viaja en el token porque las reglas lo consultan en cada
/// comprobación y ahí no cuesta nada. El perfil asociado es un dato que cambia
/// y que no tiene por qué viajar en cada petición, así que vive en un
/// documento (decisión D2).
const String coleccionUsuarios = 'usuarios';

class SesionFirebase implements Identidad {
  SesionFirebase({
    required this.auth,
    required this.firestore,
    this.almacenLocal,
  });

  /// La de verdad, con la instancia que Firebase ya tiene montada.
  ///
  /// Existe para que quien la construya **no tenga que nombrar
  /// `FirebaseAuth`**: si `main.dart` lo importara, la frontera dejaría de ser
  /// un archivo y pasaría a ser dos, y de dos se pasa a cinco sin que nadie lo
  /// decida.
  factory SesionFirebase.porOmision({
    required FirebaseFirestore firestore,
    AlmacenLocal? almacenLocal,
  }) =>
      SesionFirebase(
        auth: fb.FirebaseAuth.instance,
        firestore: firestore,
        almacenLocal: almacenLocal,
      );

  final fb.FirebaseAuth auth;
  final FirebaseFirestore firestore;

  /// Lo que hay que vaciar al cerrar sesión. Puede faltar en pruebas.
  final AlmacenLocal? almacenLocal;

  @override
  Future<EstadoDeCuenta> actual() => _estadoDe(auth.currentUser);

  @override
  Stream<EstadoDeCuenta> get cambios =>
      auth.idTokenChanges().asyncMap(_estadoDe);

  @override
  Future<void> entrar({required String correo, required String clave}) async {
    try {
      await auth.signInWithEmailAndPassword(email: correo, password: clave);
    } on fb.FirebaseAuthException catch (e) {
      throw FalloDeAcceso(_mensajeDe(e));
    }
  }

  @override
  Future<void> crearCuenta({
    required String correo,
    required String clave,
  }) async {
    try {
      await auth.createUserWithEmailAndPassword(email: correo, password: clave);
    } on fb.FirebaseAuthException catch (e) {
      throw FalloDeAcceso(_mensajeDe(e));
    }
  }

  /// Traduce el error del proveedor a algo que una persona pueda leer.
  ///
  /// Sin decir **cuál** de las dos cosas falló cuando son credenciales: «ese
  /// correo no existe» le confirma a quien prueba correos cuáles sí existen.
  String _mensajeDe(fb.FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'El correo o la contraseña no coinciden.';
      case 'email-already-in-use':
        return 'Ya hay una cuenta con ese correo. Entra en lugar de crearla.';
      case 'invalid-email':
        return 'Ese correo no tiene buena forma.';
      case 'weak-password':
        return 'Esa contraseña es muy corta. Usa al menos ocho caracteres.';
      case 'too-many-requests':
        return 'Demasiados intentos seguidos. Espera un momento.';
      case 'network-request-failed':
        return 'No hay conexión para entrar. Inténtalo cuando vuelva.';
      default:
        return 'No se pudo entrar (${error.code}).';
    }
  }

  @override
  Future<void> cerrarSesion() async {
    // El orden importa y no es casual.
    //
    // Primero se vacía lo que hay en el dispositivo, mientras todavía se sabe
    // de quién era. Después se cierra la sesión. Al revés, quedaría un rastro
    // sin dueño: datos de alguien que ya no se puede identificar para
    // borrarlos, que es la peor versión posible de este problema.
    await almacenLocal?.vaciar();

    // La caché de Firestore sobrevive al cierre de sesión si no se limpia, y
    // el siguiente que entre en este teléfono podría leer de ella. El grupo
    // son hermanos que comparten dispositivo (garantía A7).
    try {
      await firestore.terminate();
      await firestore.clearPersistence();
    } catch (_) {
      // Si la caché no se puede limpiar —web sin almacenamiento, o una
      // instancia ya terminada— no se deja a medias el cierre de sesión. Lo
      // local ya se vació, que es lo que esta app escribe.
    }

    await auth.signOut();
  }

  /// Traduce un usuario de Firebase al estado de identidad del dominio.
  ///
  /// Un token sin rol reconocible **no** se resuelve al rol menos peligroso:
  /// actuar con un permiso supuesto es justo como se cuela un acceso. Pero
  /// tampoco se trata como «no hay sesión», que es lo que hacía antes y lo que
  /// devolvía al login a quien acababa de registrarse.
  Future<EstadoDeCuenta> _estadoDe(fb.User? usuario) async {
    if (usuario == null) return const SinSesion();

    var rol = Rol.porClave(
      (await usuario.getIdTokenResult()).claims?[claveDelRol] as String?,
    );

    // Una cuenta recién creada puede tener todavía un token sin el rol: el
    // disparador que lo asigna corre después de que la cuenta exista. Se
    // refresca **una vez** antes de concluir que no hay sesión, que es lo que
    // cierra esa ventana sin pagar Identity Platform para una app de un solo
    // entrenador.
    //
    // Una sola vez y no en bucle: si tras refrescar sigue sin rol, lo que hay
    // es un token que no se entiende, y eso no se arregla insistiendo.
    if (rol == null) {
      try {
        rol = Rol.porClave(
          (await usuario.getIdTokenResult(true)).claims?[claveDelRol]
              as String?,
        );
      } on Exception {
        // Refrescar necesita red. A pie de piscina no la hay, y quedarse sin
        // rol aquí significaría echar de la app a alguien que ya tenía su
        // entrenamiento descargado (garantía A8). Se sigue con lo que trajera
        // el token guardado, que para una cuenta que ya entró alguna vez lleva
        // el rol dentro.
        rol = null;
      }
    }

    if (rol == null) return CuentaSinRol(usuario.uid);

    return CuentaLista(
      Cuenta(
        id: usuario.uid,
        rol: rol,
        nadadorId:
            rol == Rol.entrenador ? null : await _nadadorIdDe(usuario.uid),
      ),
    );
  }

  Future<String?> _nadadorIdDe(String uid) async {
    try {
      final documento =
          await firestore.collection(coleccionUsuarios).doc(uid).get();
      return documento.data()?['nadadorId'] as String?;
    } on FirebaseException {
      // Sin red y sin caché, la cuenta entra sin perfil asociado en lugar de
      // no entrar. Es un estado que la app ya sabe mostrar, y bloquear el
      // acceso por no poder leer un vínculo sería dejar a un nadador sin su
      // entrenamiento por un problema de red.
      return null;
    }
  }
}
