/// Fuera de la web no hay página que recargar.
///
/// **No es un hueco olvidado.** La app se publica como PWA: el `terminate()`
/// de `cerrarSesion` solo deja el cliente muerto donde hay una página, y es
/// ahí donde el reinicio lo arregla. En Android o en escritorio el plugin
/// guarda la instancia igual, así que el día que esta app se publique en una
/// tienda hay que resolverlo aquí —reconstruyendo la instancia o reiniciando
/// el proceso— y no suponer que el problema era de la web.
library;

Future<void> reiniciarLaApp() async {}
