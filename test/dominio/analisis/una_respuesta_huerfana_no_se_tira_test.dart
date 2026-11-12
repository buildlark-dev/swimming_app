/// Una respuesta cuya sesión no está en el plan **no se tira en silencio**.
///
/// Hallazgo del recorrido de la 010 en el Pixel 7. La siembra escribió la
/// molestia de Ana contra `s-2` y las sesiones de su plan son `s0`, `s1`,
/// `s2`. Ese error de la herramienta llevaba ahí desde la feature 008 sin que
/// nadie lo notara, porque la cola del entrenador lee las molestias **por
/// nadador** y no las empareja con ninguna sesión.
///
/// Lo que destapó es un defecto de la app, y de la familia de siempre: la
/// lista del `Análisis` marcaba «Contó una molestia» —esa consulta tampoco
/// mira sesiones— y al abrirla no había nada. **Dos pantallas de la misma app
/// diciendo cosas contrarias, con el dato en el servidor.**
///
/// El principio VIII dice que un reporte de dolor **llega al entrenador**.
/// «Llega» no admite que se caiga por el camino porque su sesión ya no esté.
///
/// Es un camino estrecho hoy —`crearVersionDesde` conserva los identificadores
/// de sesión desde la 009, y un plan aprobado es inmutable— pero estrecho no
/// es imposible: queda el dato escrito antes de aquellos arreglos, y queda
/// cualquier herramienta que se equivoque, que es justo lo que pasó aquí.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/analisis/lectura_del_nadador.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';

import 'dobles_de_analisis.dart';

void main() {
  final lunes = DateTime(2026, 11, 2);
  final hoy = DateTime(2026, 11, 20);

  test('una molestia sin sesión sigue llegando al entrenador', () async {
    final plan = mesociclo(
      id: 'p-publicado',
      sesiones: [sesionDe(id: 's0', fecha: lunes)],
    );

    final registros = RegistrosDeMentira()
      ..sembrar(registroDe(sesionId: 's0', planId: 'p-publicado', rpe: 6))
      // Apunta a una sesión que no está en el plan.
      ..sembrar(
        registroDe(
          sesionId: 's-2',
          planId: 'p-publicado',
          rpe: 7,
          molestia: const ReporteDeMolestia(
            descripcion: 'Me molesta al sacar el brazo',
            zonaDelCuerpo: 'Hombro derecho',
          ),
        ),
      );

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [plan],
      registros: registros,
      planes: PlanesDeMentira([plan]),
      hoy: hoy,
    );

    expect(lectura.sinSesion.map((r) => r.sesionId).toList(), [
      's-2',
    ], reason: 'la respuesta existe y su sesión no: eso se dice, no se tira');

    expect(
      lectura.molestiasSinSesion.single.molestia!.descripcion,
      'Me molesta al sacar el brazo',
      reason:
          'la lista del Análisis la marca leyendo la colección de registros; '
          'si la lectura la tirara, las dos pantallas se contradirían',
    );
  });

  test('sin huérfanas, las dos listas están vacías', () async {
    final plan = mesociclo(
      id: 'p-publicado',
      sesiones: [sesionDe(id: 's0', fecha: lunes)],
    );

    final registros = RegistrosDeMentira()
      ..sembrar(registroDe(sesionId: 's0', planId: 'p-publicado', rpe: 6));

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [plan],
      registros: registros,
      planes: PlanesDeMentira([plan]),
      hoy: hoy,
    );

    expect(lectura.sinSesion, isEmpty);
    expect(lectura.molestiasSinSesion, isEmpty);
    expect(lectura.respuestas.single.fueContestada, isTrue);
  });

  test('una huérfana no entra en la adherencia', () async {
    final plan = mesociclo(
      id: 'p-publicado',
      sesiones: [
        sesionDe(id: 's0', fecha: lunes),
        sesionDe(id: 's1', fecha: DateTime(2026, 11, 4)),
      ],
    );

    final registros = RegistrosDeMentira()
      ..sembrar(registroDe(sesionId: 's0', planId: 'p-publicado'))
      ..sembrar(registroDe(sesionId: 's-2', planId: 'p-publicado'));

    final lectura = await leerAlNadador(
      nadador: ana(),
      mesociclos: [plan],
      registros: registros,
      planes: PlanesDeMentira([plan]),
      hoy: hoy,
    );

    // **Se enseña, pero no se cuenta.** La adherencia cuenta sesiones
    // programadas, y una sesión que no está en el plan no se programó: meterla
    // daría «2 de 2» sobre un plan de dos sesiones del que hizo una.
    expect(lectura.adherencia.descripcion, '1 de 2');
    expect(lectura.sinSesion, hasLength(1));
  });
}
