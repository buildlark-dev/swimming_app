/// Fuera de la web no hay página que recargar, **y no hace falta**.
///
/// La feature 006 dejó aquí escrito que el problema del cliente muerto se
/// repetiría en Android «porque el plugin guarda la instancia igual». **Eso no
/// es cierto, y conviene corregirlo donde se escribió**: los dos plugins se
/// comportan al revés.
///
/// - En web, `cloud_firestore_web` guarda la instancia de JavaScript en
///   `_webFirestore ??= …` y **nadie la limpia**: después de `terminate()`
///   toda lectura falla para el resto de la vida de la página. Por eso en web
///   se recarga.
/// - En Android, `FlutterFirebaseFirestorePlugin.terminate()` llama a
///   `destroyCachedFirebaseFirestoreInstanceForKey(firestore)` y **saca la
///   instancia de su caché**. La siguiente llamada entra por
///   `getFirestoreFromPigeon`, que hace `FirebaseFirestore.getInstance(app)` y
///   le vuelve a aplicar los ajustes. El cliente se recupera solo.
///
/// Lo que el cierre de sesión promete —que no quede nada del nadador anterior
/// (garantía A7)— se cumple igual aquí: se vacía el almacén local, se vacía la
/// caché de Firestore, y el árbol de la app se reconstruye por cuenta, porque
/// la puerta del perfil lleva `ValueKey(cuenta.id)`.
///
/// Esto está leído del fuente del plugin, no supuesto. Falta verlo en un
/// Android de verdad: es el caso C11 del quickstart de la feature 007.
library;

Future<void> reiniciarLaApp() async {}
