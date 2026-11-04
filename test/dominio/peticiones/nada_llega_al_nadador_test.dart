/// Garantía P18 y FR-012 — pedir no entrega nada.
///
/// Es la promesa central de la feature, y se comprueba **sobre los
/// repositorios y no sobre una pantalla**: que algo no se vea es una cosa, y
/// que no exista es otra. Lo que el principio IV exige es lo segundo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';

import '../../ui/peticion/ayuda_peticion.dart';

void main() {
  final hoy = DateTime(2026, 11, 2);

  RespuestasDePeticion respuestas() => RespuestasDePeticion(
    estiloObjetivo: Estilo.libre,
    pruebaObjetivo: '200 Libre',
    fechaDeCompetencia: hoy.add(const Duration(days: 24)),
    diasDisponibles: [
      hoy.add(const Duration(days: 1)),
      hoy.add(const Duration(days: 3)),
    ],
    duracionSesionMinutos: 90,
    longitudPiscina: 25,
  );

  test('mandar una petición no crea plan, ni asignación, ni sesión', () async {
    final planes = RepositorioPlanesMemoria();
    final asignaciones = RepositorioAsignacionesMemoria();
    final peticiones = PeticionesEnMemoria();

    await peticiones.enviar(nadadorId: 'n-ana', respuestas: respuestas());

    expect(
      await planes.listar(),
      isEmpty,
      reason: 'Pedir no genera: el borrador nace cuando el entrenador abre',
    );
    expect(await asignaciones.deNadador('n-ana'), isEmpty);
  });

  test('la petición guardada no lleva el plan dentro', () async {
    final peticiones = PeticionesEnMemoria();
    await peticiones.enviar(nadadorId: 'n-ana', respuestas: respuestas());

    final mia = await peticiones.miPeticion('n-ana');

    expect(mia, isNotNull);
    expect(
      mia!.planId,
      isNull,
      reason:
          'Lo que el nadador puede leer se decide por dónde está guardado, no '
          'por lo que la pantalla enseñe',
    );
    expect(mia.estado, EstadoDePeticion.esperando);
  });

  test('y lo que lleva es lo que él respondió, para poder auditarlo', () async {
    final peticiones = PeticionesEnMemoria();
    await peticiones.enviar(nadadorId: 'n-ana', respuestas: respuestas());

    final mia = await peticiones.miPeticion('n-ana');

    expect(mia!.respuestas.pruebaObjetivo, '200 Libre');
    expect(mia.respuestas.diasDisponibles, hasLength(2));
    expect(mia.respuestas.longitudPiscina, 25);
  });
}
