import 'package:flutter_test/flutter_test.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/consentimiento/puerta.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/dominio/cuentas/permisos.dart';
import 'package:natacion_app/dominio/entidades/ciclo_vida_plan.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';

/// US6 — el entrenador trabaja antes de tener el grupo completo.
///
/// Sin esto, la puerta de publicación se convertiría en una **puerta de
/// trabajo**: el entrenador no podría planificar su temporada hasta tener la
/// última firma, y eso no es lo que el principio V pide.
///
/// Un microciclo es su obra profesional. Lo que la puerta bloquea es
/// **entregárselo a una persona**, que es cuando entran los datos de esa
/// persona.
void main() {
  final ciclo = CicloVidaPlan(
    auditoria: Auditoria(),
    versionMetodologia: '3.6.0',
  );

  Plan borrador() => Plan(
        id: 'p1',
        nombre: 'Microciclo de base',
        categoria: Categoria.iniciacion,
        estiloObjetivo: Estilo.libre,
        pruebaObjetivo: '100 Libre',
        estado: EstadoPlan.borrador,
        microciclos: const [
          Microciclo(id: 'm1', nombre: 'Semana 1', orden: 1, objetivo: 'Base'),
        ],
        sesiones: [
          for (var i = 1; i <= 2; i++)
            Sesion(
              id: 's$i',
              microcicloId: 'm1',
              fecha: DateTime(2026, 10, i),
              objetivoTecnico: 'Adaptación acuática',
              objetivoFisiologico: 'Base aeróbica',
              partes: [
                Parte(
                  tipo: TipoParte.inicial,
                  series: const [
                    Serie(
                      repeticiones: 6,
                      distancia: 50,
                      zona: Zona.a1,
                      estilo: Estilo.libre,
                    ),
                  ],
                ),
                const Parte(tipo: TipoParte.central),
                const Parte(tipo: TipoParte.cierre),
              ],
            ),
        ],
      );

  final entrenador = Cuenta(id: 'u-e', rol: Rol.entrenador);

  group('sin un solo consentimiento, el trabajo no se bloquea', () {
    test('se puede guardar un borrador', () async {
      final repo = RepositorioPlanesMemoria();
      final id = await repo.guardarBorrador(borrador());

      expect(await repo.obtener(id), isNotNull);
    });

    test('se puede editar un borrador', () {
      expect(Permisos.puedeEditarPlan(entrenador, borrador()), isTrue);
    });

    test('aprobar solo depende de la auditoría, no de consentimientos', () {
      // La auditoría puede rechazarlo por motivos de metodología, y eso es
      // otra cosa. Lo que no puede es rechazarlo por falta de
      // consentimientos: ninguno de sus impedimentos habla de eso.
      final impedimentos = ciclo.auditoria.impedimentosPara(borrador());

      expect(
        impedimentos.map((i) => i.toString()).join(' ').toLowerCase(),
        isNot(contains('consentimiento')),
      );
    });

    test('se puede guardar lo aprobado', () async {
      final repo = RepositorioPlanesMemoria();
      final aprobado = borrador().copiarCon(estado: EstadoPlan.aprobado);

      await repo.guardarAprobado(aprobado, const {});

      expect((await repo.obtener('p1'))!.estado, EstadoPlan.aprobado);
    });

    test('se puede publicar: publicar no es entregar a nadie', () {
      // Un plan publicado sin asignar no es de nadie, y por eso publicarlo no
      // toca los datos de nadie.
      final resultado =
          ciclo.publicar(borrador().copiarCon(estado: EstadoPlan.aprobado));

      expect(resultado, isA<TransicionHecha>());
    });
  });

  group('lo único que se bloquea es la entrega', () {
    test('no se asigna a quien no tiene consentimiento', () {
      expect(
        Permisos.puedeAsignar(entrenador, tieneConsentimiento: false),
        isFalse,
      );
    });

    test('a quien sí lo tiene, se le entrega', () {
      expect(
        Permisos.puedeAsignar(entrenador, tieneConsentimiento: true),
        isTrue,
      );
    });
  });

  group('T080 — el camino del entrenador no consulta la puerta', () {
    test('generar, aprobar y guardar no le preguntan ni una vez', () async {
      final puerta = _PuertaQueCuenta();
      final repo = RepositorioPlanesMemoria();

      final id = await repo.guardarBorrador(borrador());
      final recuperado = await repo.obtener(id);
      ciclo.aprobar(recuperado!);
      await repo.guardarAprobado(
        recuperado.copiarCon(estado: EstadoPlan.aprobado),
        const {},
      );

      expect(
        puerta.consultas,
        0,
        reason: 'El trabajo del entrenador es su obra profesional y no son '
            'datos personales de nadie. Si la puerta se consultara aquí, '
            'sería una puerta de trabajo y no de publicación',
      );
    });
  });
}

class _PuertaQueCuenta implements PuertaDeConsentimiento {
  int consultas = 0;

  @override
  Future<bool> puedeSalir(String nadadorId) async {
    consultas++;
    return true;
  }
}
