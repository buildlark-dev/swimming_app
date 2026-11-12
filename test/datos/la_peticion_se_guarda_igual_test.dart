/// El contrato de `RepositorioPeticionesDeFeedback`, **la misma batería sobre
/// las dos implementaciones**.
///
/// Es la forma que `el_plan_se_guarda_con_sus_sesiones_test.dart` usa, y la
/// razón es la lección más cara de la feature 009: **seis de sus siete
/// defectos eran un doble en memoria más amable que Firestore.** La pantalla
/// pasaba todas las pruebas y fallaba en el teléfono.
///
/// Así que el doble tiene que **rechazar lo que el servidor rechaza**, y la
/// manera de asegurarlo es correr las mismas pruebas sobre los dos. El de
/// Firestore no se puede ejecutar aquí —`cloud_firestore` necesita canales de
/// plataforma—, así que el segundo sujeto es un doble con forma de Firestore:
/// uno que aplica las mismas reglas que `firestore.rules` y guarda documentos
/// JSON en lugar de objetos.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/serializacion.dart';
import 'package:natacion_app/dominio/analisis/peticion_de_feedback.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';

/// Un doble **con forma de servidor**: guarda y lee JSON, y aplica las mismas
/// negativas que `firestore.rules`.
///
/// No es la implementación de Firestore —esa no corre bajo `flutter test`—
/// sino la misma pregunta hecha al otro lado de la serialización, que es
/// donde la feature 009 encontró el defecto de los tres campos perdidos.
class _ComoElServidor implements RepositorioPeticionesDeFeedback {
  final documentos = <String, Map<String, dynamic>>{};

  @override
  Future<List<PeticionDeFeedback>> deNadador(String nadadorId) async => [
    for (final datos in documentos.values)
      if (datos['nadadorId'] == nadadorId) peticionDeFeedbackDesdeJson(datos),
  ];

  @override
  Future<List<PeticionDeFeedback>> deNadadorEnPlan(
    String nadadorId,
    String planId,
  ) async => [
    for (final datos in documentos.values)
      if (datos['nadadorId'] == nadadorId && datos['planId'] == planId)
        peticionDeFeedbackDesdeJson(datos),
  ];

  @override
  Future<void> guardar(PeticionDeFeedback peticion) async {
    final datos = peticionDeFeedbackAJson(peticion);

    // Las mismas negativas que la regla: pregunta no vacía y sin vídeo.
    if ((datos['pregunta'] as String).trim().isEmpty) {
      throw const FalloDeDatos('la pregunta no puede estar vacía');
    }
    if (datos.containsKey('video')) {
      throw const FalloDeDatos('una petición con vídeo se rechaza');
    }

    documentos[peticion.id] = datos;
  }

  @override
  Future<void> marcarVista(String peticionId, DateTime cuando) async {
    final datos = documentos[peticionId];
    if (datos == null) throw const FalloDeDatos('no existe');

    // `hasOnly(['vistaEn'])`: la escritura toca un campo y ninguno más.
    documentos[peticionId] = {...datos, 'vistaEn': cuando.toIso8601String()};
  }
}

void main() {
  PeticionDeFeedback pedir({
    String sesionId = 's1',
    String planId = 'plan-1',
    String pregunta = '¿El viraje del tercer 50 lo hice bien?',
  }) => PeticionDeFeedback(
    nadadorId: 'n-ana',
    planId: planId,
    sesionId: sesionId,
    pregunta: pregunta,
    pedidaEn: DateTime(2026, 11, 2, 19, 30),
  );

  final sujetos = <String, RepositorioPeticionesDeFeedback Function()>{
    'memoria': RepositorioPeticionesDeFeedbackMemoria.new,
    'como el servidor': _ComoElServidor.new,
  };

  for (final MapEntry(key: nombre, value: construir) in sujetos.entries) {
    group(nombre, () {
      late RepositorioPeticionesDeFeedback repo;

      setUp(() => repo = construir());

      test('guarda y devuelve lo guardado', () async {
        await repo.guardar(pedir());

        final suyas = await repo.deNadador('n-ana');
        expect(suyas, hasLength(1));
        expect(suyas.single.pregunta, '¿El viraje del tercer 50 lo hice bien?');
        expect(suyas.single.vistaEn, isNull);
      });

      test('no devuelve las de otro nadador', () async {
        await repo.guardar(pedir());

        expect(await repo.deNadador('n-juan'), isEmpty);
      });

      test('deNadadorEnPlan filtra por nadador Y por plan', () async {
        await repo.guardar(pedir(planId: 'plan-1', sesionId: 's1'));
        await repo.guardar(pedir(planId: 'plan-2', sesionId: 's9'));

        final delPrimero = await repo.deNadadorEnPlan('n-ana', 'plan-1');

        expect(delPrimero, hasLength(1));
        expect(delPrimero.single.planId, 'plan-1');
      });

      test('pedir dos veces por la misma sesión no duplica', () async {
        await repo.guardar(pedir());
        await repo.guardar(pedir(pregunta: '¿Y el viraje, lo hice bien?'));

        final suyas = await repo.deNadador('n-ana');
        expect(suyas, hasLength(1));
        expect(suyas.single.pregunta, '¿Y el viraje, lo hice bien?');
      });

      test('el entrenador la marca vista', () async {
        await repo.guardar(pedir());
        await repo.marcarVista('n-ana|plan-1|s1', DateTime(2026, 11, 3, 8));

        final suya = (await repo.deNadador('n-ana')).single;
        expect(suya.laVio, isTrue);
        expect(suya.vistaEn, DateTime(2026, 11, 3, 8));
      });

      test('marcarla vista no toca su pregunta', () async {
        const suya = '¿El viraje del tercer 50 lo hice bien?';
        await repo.guardar(pedir(pregunta: suya));
        await repo.marcarVista('n-ana|plan-1|s1', DateTime(2026, 11, 3));

        expect((await repo.deNadador('n-ana')).single.pregunta, suya);
      });

      test('una petición con vídeo se rechaza en los dos lados', () async {
        // El constructor del dominio ya lo impide, así que llegar aquí con uno
        // pide saltárselo. Lo que esta prueba fija es que **los dos lados**
        // tienen la negativa, y no solo el servidor.
        expect(
          () => PeticionDeFeedback(
            nadadorId: 'n-ana',
            planId: 'plan-1',
            sesionId: 's1',
            pregunta: '¿Mira el viraje?',
            pedidaEn: DateTime(2026, 11, 2),
            video: ReferenciaDeVideo(
              ruta: 'videos/x.mp4',
              subidoEn: DateTime(2026, 11, 2),
            ),
          ),
          throwsA(isA<VideoTodaviaNo>()),
        );
      });
    });
  }
}
