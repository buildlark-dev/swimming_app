/// Los repositorios que el HUB usa, en un solo sitio.
///
/// Estaban como campos `late final` dentro del estado de la pantalla
/// principal, cada uno con su «si hay Firestore, el de Firestore; si no, el de
/// memoria». Salen aquí por dos razones:
///
/// 1. Esa decisión es una sola y se lee de un tirón.
/// 2. **Se pueden sembrar.** Con los repositorios dentro del estado no había
///    forma de montar el HUB en una prueba con un nadador, un plan y unos
///    registros, así que el recorrido del nadador no se podía comprobar.
library;

import 'package:natacion_app/datos/firestore/consentimientos.dart';
import 'package:natacion_app/datos/firestore/peticiones_firestore.dart';
import 'package:natacion_app/datos/peticiones/peticiones_con_puerta.dart';
import 'package:natacion_app/datos/firestore/registros_firestore.dart';
import 'package:natacion_app/datos/firestore/repositorios_firestore.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/datos/local/repositorios_locales.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/recursos/recursos_iniciales.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

class RepositoriosDelHub {
  const RepositoriosDelHub({
    required this.planes,
    required this.sesiones,
    required this.nadadores,
    required this.asignaciones,
    required this.registrosLocales,
    this.registrosDelServidor,
    this.peticiones,
  });

  /// Los de verdad: con servidor persisten; sin él, no.
  ///
  /// Hasta la feature 004 `main.dart` usaba los de memoria **aunque los de
  /// Firestore existieran desde la 001**: estaban escritos y nadie los
  /// llamaba, y el trabajo del entrenador se perdía al recargar.
  factory RepositoriosDelHub.de(
    RecursosIniciales recursos,
    AlmacenLocal almacen,
  ) {
    final db = recursos.firestore;

    final sesiones = db == null
        ? RepositorioSesionesMemoria()
        : RepositorioSesionesFirestore(db, recursos.biblioteca);

    return RepositoriosDelHub(
      planes: db == null
          ? RepositorioPlanesMemoria()
          : RepositorioPlanesFirestore(db, recursos.biblioteca, sesiones),
      sesiones: sesiones,
      nadadores: db == null
          ? RepositorioNadadoresMemoria()
          : RepositorioNadadoresFirestore(db),
      asignaciones: db == null
          ? RepositorioAsignacionesMemoria()
          : RepositorioAsignacionesFirestore(db),
      registrosLocales: RegistrosLocales(almacen),
      // Para saber quién ha respondido algo hace falta leer la colección del
      // servidor, no el almacén de este dispositivo. Sin servidor no hay a
      // quién preguntar y el resumen cuenta con lo local.
      registrosDelServidor: db == null ? null : RegistrosFirestore(db),
      // Sin servidor no hay peticiones: no hay a quien pedirle nada ni donde
      // guardarlo. La pantalla lo dice en lugar de ofrecer una lista que no
      // lleva a ninguna parte.
      // **Pasando por la puerta del menor.** No es un tercer camino para
      // salir del dispositivo: es el mismo que la 003 montó para los
      // registros, con la puerta que la 004 construyó.
      peticiones: db == null
          ? null
          : PeticionesConPuerta(
              servidor: PeticionesFirestore(db),
              puerta: PuertaFirestore(db),
              almacen: almacen,
            ),
    );
  }

  final RepositorioPlanes planes;
  final RepositorioSesiones sesiones;
  final RepositorioNadadores nadadores;
  final RepositorioAsignaciones asignaciones;

  /// Donde el nadador escribe. **Primero el dispositivo**, siempre.
  final RepositorioRegistros registrosLocales;

  /// Donde el entrenador mira quién ha respondido. Nulo sin servidor.
  final RepositorioRegistros? registrosDelServidor;

  /// Lo que los nadadores piden (feature 008). Nulo sin servidor.
  final RepositorioPeticiones? peticiones;

  /// Si lo que mandó un nadador sigue retenido en el dispositivo.
  Future<bool> estaRetenida(String nadadorId) async {
    final repo = peticiones;
    return repo is PeticionesConPuerta ? repo.estaRetenida(nadadorId) : false;
  }

  /// Lo que el resumen del entrenador consulta para contar «en uso».
  RepositorioRegistros get registrosParaContar =>
      registrosDelServidor ?? registrosLocales;
}
