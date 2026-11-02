/// Todo lo que la app necesita cargar antes de empezar.
///
/// Vivía dentro de `main.dart` hasta la feature 007. Sale aquí porque el HUB lo
/// consume y `main.dart` lo construye: dejarlo donde estaba obligaría al HUB a
/// importar el archivo de arranque, que a su vez importa el HUB.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:natacion_app/datos/servidor/operaciones.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class RecursosIniciales {
  const RecursosIniciales({
    required this.biblioteca,
    required this.versionMetodologia,
    required this.indiceTerminos,
    required this.red,
    required this.transporte,
    this.identidad,
    this.operaciones,
    this.firestore,
  });

  final Biblioteca biblioteca;
  final String versionMetodologia;

  /// Vocabulario de diagnóstico del entrenador. Puede venir vacío: entonces
  /// los diagnósticos se reportan como vacío de Biblioteca en lugar de
  /// resolverse con un ejercicio aproximado.
  final IndiceTerminos indiceTerminos;

  /// Si hay red, para el recorrido del nadador (feature 003).
  final EstadoDeRed red;

  /// Quién lleva los registros del nadador a su destino.
  final EnvioDeRegistros transporte;

  /// Quién está usando la app (feature 004).
  ///
  /// Nula cuando no hay servidor con el que hablar. Entonces la app entra en
  /// **modo local**, que es el modo en que se desarrolla sin levantar los
  /// emuladores y en el que no hay rol que consultar.
  final Identidad? identidad;

  /// Las operaciones del servidor (feature 006).
  ///
  /// Nulas sin servidor, por lo mismo que [identidad]. Sin ellas el alta no
  /// puede guardar el perfil y el acudiente no puede canjear su enlace, y las
  /// dos pantallas lo dicen en lugar de fingir que funcionan.
  final OperacionesDelServidor? operaciones;

  /// La base de datos, si la hay. Nula en modo local.
  ///
  /// Es lo que decide si el trabajo del entrenador sobrevive al cierre de la
  /// app o se pierde al recargar.
  final FirebaseFirestore? firestore;
}
