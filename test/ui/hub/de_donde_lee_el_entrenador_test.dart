/// El entrenador lee del **servidor**, no de su dispositivo.
///
/// Es la mitad que faltaba. La feature 009 cerró la del nadador con
/// `RegistrosDeLasDosPartes` —su teléfono y el servidor, ganando lo local—
/// porque lo que él escribió está primero en su aparato y todavía puede estar
/// en la bandeja de salida. Para el entrenador eso no vale, y no es un detalle
/// de eficiencia: **su dispositivo nunca escribió las respuestas de ella**, así
/// que «gana lo local» no tiene nada que ganar y lo único que añade es una
/// lectura del almacén de su teléfono, donde no hay nada de ella.
///
/// Peor si alguna vez hubiera algo: el entrenador que prueba la app como su
/// propio nadador —que es como se probó la feature 003— dejaría registros
/// locales suyos que se mezclarían con los de la nadadora.
///
/// Decisión D3 de `research.md`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/registros_de_las_dos_partes.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/hub/repositorios_del_hub.dart';

import '../../dominio/analisis/dobles_de_analisis.dart';

RepositoriosDelHub hub({RepositorioRegistros? servidor}) {
  final sesiones = RepositorioSesionesMemoria();
  return RepositoriosDelHub(
    planes: RepositorioPlanesMemoria(sesiones: sesiones),
    sesiones: sesiones,
    nadadores: RepositorioNadadoresMemoria(),
    asignaciones: RepositorioAsignacionesMemoria(),
    macrociclos: RepositorioMacrociclosMemoria(),
    registrosLocales: RegistrosDeMentira(),
    registrosDelServidor: servidor,
  );
}

void main() {
  test('con servidor, el entrenador lee del servidor', () {
    final servidor = RegistrosDeMentira();

    expect(hub(servidor: servidor).registrosParaElEntrenador, same(servidor));
  });

  test('el lector del entrenador no es el de las dos partes', () {
    expect(
      hub(servidor: RegistrosDeMentira()).registrosParaElEntrenador,
      isNot(isA<RegistrosDeLasDosPartes>()),
      reason:
          'leer «ganando lo local» en el teléfono del entrenador suma una '
          'lectura de un almacén donde no hay nada de ella, y mezcla sus '
          'propios registros de prueba con los de la nadadora',
    );
  });

  test('sin servidor cae en lo local en lugar de fallar en cada lectura', () {
    final sinServidor = hub();

    expect(
      sinServidor.registrosParaElEntrenador,
      same(sinServidor.registrosLocales),
      reason:
          'en modo local no hay a quién preguntar, y dejar el lector nulo '
          'convertiría cada lectura del Análisis en un fallo',
    );
  });

  test('el nadador sigue leyendo de las dos partes', () {
    expect(
      hub(servidor: RegistrosDeMentira()).registrosDelNadador,
      isA<RegistrosDeLasDosPartes>(),
      reason: 'lo que él escribió está primero en su dispositivo (feature 009)',
    );
  });
}
