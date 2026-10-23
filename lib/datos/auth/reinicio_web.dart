/// Recargar la página.
///
/// Es exactamente lo que el entrenador hacía a mano —cerrar la PWA y abrirla
/// de nuevo— cuando cerrar sesión dejaba la app sin poder leer nada. Hecho por
/// la app, en el único sitio que sabe que hizo falta.
///
/// `location.reload()` y no `assign('/')`: lo que hace falta es un cliente de
/// Firestore nuevo, no una ruta nueva. Y la sesión ya está cerrada cuando esto
/// corre, así que la página que vuelve es la de acceso.
library;

import 'package:web/web.dart' as web;

Future<void> reiniciarLaApp() async {
  web.window.location.reload();
}
