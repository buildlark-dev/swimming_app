/// Arrancar la app de nuevo.
///
/// Existe por una sola llamada: la de `cerrarSesion`. Vaciar la caché de
/// Firestore obliga a terminar el cliente, y el plugin **no vuelve a crearlo**
/// —guarda la instancia en un campo que nadie limpia—, así que a partir de ahí
/// toda lectura falla con «el cliente ya se ha terminado» hasta que la página
/// se carga otra vez.
///
/// Es un puerto con dos implementaciones porque recargar la página solo existe
/// en la web. En la web es lo que arregla el fallo; fuera de ella no hay página
/// que recargar y la llamada no hace nada, dicho a propósito en lugar de
/// dejarlo pasar en silencio: el día que esta app se publique en Android, el
/// vaciado de la caché volverá a dejar el cliente muerto y habrá que resolverlo
/// allí.
library;

export 'reinicio_nativo.dart'
    if (dart.library.js_interop) 'reinicio_web.dart';
