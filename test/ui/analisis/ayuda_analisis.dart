/// Lo que hace falta para montar el `Análisis` del entrenador.
///
/// En un archivo aparte porque lo usan seis pruebas: sembrar un macrociclo con
/// sus mesociclos y unos registros no se escribe seis veces.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/peticiones/molestias_enlazadas.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/analisis/lectura_de_un_nadador.dart';
import 'package:natacion_app/ui/analisis/pantalla_analisis.dart';
import 'package:natacion_app/ui/tema/tema.dart';

import '../../dominio/analisis/dobles_de_analisis.dart';

// Para que las pruebas de esta carpeta no tengan que importar los dos.
export '../../dominio/analisis/dobles_de_analisis.dart';

/// Hoy, fijo. Una prueba que depende del día real se pone roja sola: pasó en
/// la feature 007 con cuatro pruebas del HUB.
final DateTime hoyDePrueba = DateTime(2026, 11, 20);

final DateTime lunes = DateTime(2026, 11, 2);
final DateTime miercoles = DateTime(2026, 11, 4);
final DateTime viernes = DateTime(2026, 11, 6);

/// Una pantalla alta, para que lo que se mide sea el contenido y no el recorte.
void conPantallaAlta(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class ReposDeAnalisis {
  ReposDeAnalisis();

  final nadadores = RepositorioNadadoresMemoria();
  final macrociclos = RepositorioMacrociclosMemoria();
  final registros = RegistrosDeMentira();
  late final planes = PlanesDeMentira();

  /// Siembra un macrociclo entregado con dos mesociclos y devuelve su id.
  Future<String> sembrarMacrociclo({
    String nadadorId = 'n-ana',
    List<Plan>? mesociclos,
  }) async {
    final suyos =
        mesociclos ??
        [
          mesociclo(
            id: 'plan-1',
            orden: 0,
            sesiones: [
              sesionDe(id: 's1', fecha: lunes),
              sesionDe(id: 's2', fecha: miercoles),
              sesionDe(id: 's3', fecha: viernes),
            ],
          ),
        ];

    for (final plan in suyos) {
      planes.sembrar(plan);
    }

    final id = await macrociclos.guardarBorrador(
      Macrociclo(
        nadadorId: nadadorId,
        nombre: 'Hacia el Departamental',
        estructura: _estructura(),
        mesociclos: [for (final p in suyos) p.id!],
        fechaDeCompetencia: DateTime(2026, 12, 13),
        versionMetodologia: '3.6.0',
      ),
    );

    await macrociclos.guardarAprobado(
      (await macrociclos.obtener(id))!.copiarCon(estado: EstadoPlan.aprobado),
      const {},
    );
    await macrociclos.publicar(id);

    return id;
  }
}

EstructuraConfirmada _estructura() => EstructuraConfirmada(
  modeloDeLaPrueba: '200 libre: umbral alto, viraje y salida.',
  modeloDelNadador: 'Crol dominante, pierde el agarre al fatigarse.',
  bloques: [
    BloqueConfirmado(
      fase: FaseAtr.acumulacion,
      desde: DateTime(2026, 11, 1),
      hasta: DateTime(2026, 11, 28),
      porQue: 'Acumulación, las primeras cuatro semanas.',
    ),
  ],
  confirmadaEn: DateTime(2026, 10, 31),
  diasPorSemana: const [1, 3, 5],
  duracionSesionMinutos: 90,
  longitudPiscina: 25,
);

/// Molestias sembradas a mano, como las lee el entrenador.
class MolestiasSembradas implements LectorDeMolestias {
  MolestiasSembradas([this.quienes = const <String>{}]);

  Set<String> quienes;

  final Map<String, List<MolestiaEnlazada>> porNadador = {};

  @override
  Future<List<MolestiaEnlazada>> recientesDe(
    String nadadorId, {
    required DateTime desde,
  }) async => porNadador[nadadorId] ?? const [];

  @override
  Future<Set<String>> quienesReportaron({required DateTime desde}) async =>
      quienes;
}

/// Monta la lista de nadadores del `Análisis`.
Widget montarAnalisis({
  required ReposDeAnalisis repos,
  LectorDeMolestias? molestias,
}) => MaterialApp(
  theme: Tema.claro(),
  home: Scaffold(
    body: PantallaAnalisis(
      nadadores: repos.nadadores,
      macrociclos: repos.macrociclos,
      planes: repos.planes,
      registros: repos.registros,
      molestias: molestias,
      hoy: hoyDePrueba,
    ),
  ),
);

/// Monta la lectura de un nadador, sin pasar por la lista.
Widget montarLectura({
  required ReposDeAnalisis repos,
  required String macrocicloId,
  Nadador? nadador,
  RepositorioRegistros? registros,
}) => MaterialApp(
  theme: Tema.claro(),
  home: Scaffold(
    body: LecturaDeUnNadador(
      nadador: nadador ?? ana(),
      macrocicloId: macrocicloId,
      macrociclos: repos.macrociclos,
      planes: repos.planes,
      registros: registros ?? repos.registros,
      hoy: hoyDePrueba,
    ),
  ),
);

/// Un registro con molestia, para US2.
RegistroDeSesion conMolestia({
  required String sesionId,
  required String planId,
  String descripcion = 'Me molesta el hombro derecho al salir',
  String zona = 'Hombro derecho',
}) => registroDe(
  sesionId: sesionId,
  planId: planId,
  rpe: 6,
  molestia: ReporteDeMolestia(descripcion: descripcion, zonaDelCuerpo: zona),
);
