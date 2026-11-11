/// Un plan que va por su cuenta sigue yendo por su cuenta (feature 009, D1).
///
/// `Plan` gana dos campos nulos —`macrocicloId` y `ordenEnElMacrociclo`— y
/// nada más. Esta prueba fija la mitad que se puede perder sin que nada falle:
/// que un plan nacido de una petición de la feature 008, o escrito a mano,
/// **no se cuelgue de ningún macrociclo**.
///
/// Importa porque la suposición está escrita en la spec: «un plan firmado por
/// su cuenta no es absorbido por un macrociclo que llega después». Si un día
/// la derivación pusiera `macrocicloId` por defecto, la cola del entrenador
/// empezaría a tratar los borradores de petición como mesociclos de algo, y la
/// pantalla no se quejaría.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/generar_desde_peticion.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';

void main() {
  final hoy = DateTime(2026, 11, 2);

  Biblioteca biblioteca() => Biblioteca.desdeJson(
    jsonDecode(File('assets/biblioteca/ejercicios.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  PeticionDePlan peticion() => PeticionDePlan(
    nadadorId: 'n-ana',
    enviadaEn: hoy,
    estado: EstadoDePeticion.esperando,
    respuestas: RespuestasDePeticion(
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '200 Libre',
      fechaDeCompetencia: hoy.add(const Duration(days: 24)),
      diasDisponibles: [
        for (var i = 1; i <= 3; i++) hoy.add(Duration(days: i * 2)),
      ],
      duracionSesionMinutos: 90,
      longitudPiscina: 25,
    ),
  );

  test('un plan recién construido no pertenece a ningún macrociclo', () {
    const plan = Plan(
      nombre: 'Técnica de eficiencia',
      categoria: Categoria.precompetitivo,
      estiloObjetivo: Estilo.libre,
    );

    expect(plan.macrocicloId, isNull);
    expect(plan.ordenEnElMacrociclo, isNull);
  });

  test('el borrador que sale de una petición va por su cuenta', () {
    final borrador = generarDesdePeticion(
      peticion: peticion(),
      ficha: const Nadador(
        id: 'n-ana',
        nombre: 'Ana María Restrepo',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.libre,
        pruebaObjetivo: '200 Libre',
      ),
      biblioteca: biblioteca(),
      versionMetodologia: '3.6.0',
      hoy: hoy,
    );

    final resultado = borrador.resultado;
    expect(resultado, isA<MicrocicloGenerado>());

    final plan = (resultado! as MicrocicloGenerado).plan;

    // Lo que la feature 008 marcó sigue marcado...
    expect(plan.peticionId, 'n-ana');
    // ...y lo que la 009 añade sigue vacío: el macrociclo no lo reclama.
    expect(plan.macrocicloId, isNull);
    expect(plan.ordenEnElMacrociclo, isNull);
  });

  test(
    '`copiarCon(id: null)` NO borra el identificador, y conviene saberlo',
    () {
      // **Esta prueba existe porque la trampa ya costó un diagnóstico.**
      //
      // `copiarCon` resuelve cada campo como `nuevo ?? this.campo`, así que
      // pasar nulo significa «no lo cambies», no «ponlo a nulo». Una línea como
      // `sesion.copiarCon(id: null)` **parece** que quita el identificador y no
      // lo quita, y leyéndola de corrido se concluye lo contrario de lo que el
      // código hace. Pasó al planificar la feature 009: se dio por defecto que
      // `crearVersionDesde` renombraba las sesiones de cada versión, y no las
      // renombraba.
      //
      // Vale para `Plan` y para `Sesion` por igual. Si algún día hace falta
      // poder vaciar un campo, lo que hay que añadir es un parámetro explícito
      // —un centinela o un `bool quitarEl...`—, no confiar en el nulo.
      final sesion = Sesion(id: 's1', microcicloId: 'mc-1');
      expect(sesion.copiarCon(id: null).id, 's1');

      const plan = Plan(
        id: 'p1',
        nombre: 'Mesociclo',
        categoria: Categoria.competitivo,
        estiloObjetivo: Estilo.libre,
        macrocicloId: 'macro-1',
      );
      expect(plan.copiarCon(id: null).id, 'p1');
      expect(plan.copiarCon(macrocicloId: null).macrocicloId, 'macro-1');
    },
  );

  test('`copiarCon` conserva la pertenencia al macrociclo', () {
    const mesociclo = Plan(
      nombre: 'Umbral y ritmo competitivo',
      categoria: Categoria.competitivo,
      estiloObjetivo: Estilo.libre,
      macrocicloId: 'macro-1',
      ordenEnElMacrociclo: 2,
    );

    // Editar el nombre no saca al mesociclo de su macrociclo. Perderlo ahí
    // dejaría un mesociclo huérfano dentro de una preparación que sigue
    // nombrándolo.
    final editado = mesociclo.copiarCon(nombre: 'Umbral, semana 2');
    expect(editado.macrocicloId, 'macro-1');
    expect(editado.ordenEnElMacrociclo, 2);
  });
}
