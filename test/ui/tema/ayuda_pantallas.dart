/// Las pantallas de la app, montadas para medirlas.
///
/// Las garantías V6 y V7 no se comprueban sobre un widget inventado: se
/// comprueban **sobre las pantallas que el nadador y el entrenador abren**. Un
/// banco de pruebas que mide un `Column` de juguete siempre pasa.
///
/// Vive en un archivo aparte porque lo usan dos pruebas —el tamaño de letra y
/// el área pulsable— y porque montar estas pantallas tiene suficiente
/// andamiaje como para no escribirlo dos veces.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/envio_pendiente.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/parte.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/serie.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/acceso/pantalla_acceso.dart';
import 'package:natacion_app/ui/editor/estado_editor.dart';
import 'package:natacion_app/ui/editor/pantalla_editor.dart';
import 'package:natacion_app/ui/generacion/pantalla_peticion.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/pantalla_mi_progreso.dart';
import 'package:natacion_app/ui/nadador/pantalla_sesion_del_dia.dart';
import 'package:natacion_app/ui/nadadores/pantalla_perfiles.dart';
import 'package:natacion_app/ui/planes/pantalla_plan.dart';
import 'package:provider/provider.dart';

/// Una pantalla con nombre, para que el fallo diga cuál.
class PantallaMedible {
  const PantallaMedible(this.nombre, this.construir);

  final String nombre;
  final Widget Function() construir;

  @override
  String toString() => nombre;
}

final DateTime _hoy = DateTime(2026, 10, 20, 7);

Biblioteca _biblioteca() => Biblioteca.desdeJson(
      jsonDecode(File('assets/biblioteca/ejercicios.json').readAsStringSync())
          as Map<String, dynamic>,
    );

/// Contenido real, no «abc».
///
/// Un texto corto nunca desborda. Lo que desborda es «Precompetitivo ·
/// 1800-2200 m · 3 sesiones» al 200%, y por eso lo que se monta aquí son las
/// cadenas que la app enseña de verdad.
Sesion _sesion({required String id, required DateTime fecha}) => Sesion(
      id: id,
      microcicloId: 'm1',
      fecha: fecha,
      objetivoTecnico: 'Técnica de eficiencia en Libre',
      objetivoFisiologico: 'Base aeróbica con énfasis en economía de nado',
      partes: [
        const Parte(
          tipo: TipoParte.inicial,
          textoOriginal: "4x100 AL / 2'",
          series: [
            Serie(
              repeticiones: 4,
              distancia: 100,
              zona: Zona.a1,
              estilo: Estilo.libre,
            ),
          ],
        ),
        const Parte(
          tipo: TipoParte.central,
          textoOriginal: '8x50 Libre máx / 1\'30"',
          series: [
            Serie(
              repeticiones: 8,
              distancia: 50,
              zona: Zona.resistenciaIntensiva,
              estilo: Estilo.libre,
            ),
          ],
        ),
        const Parte(tipo: TipoParte.cierre),
      ],
    );

Plan _plan() => Plan(
      id: 'p1',
      nombre: 'Microciclo de base aeróbica',
      categoria: Categoria.precompetitivo,
      estiloObjetivo: Estilo.libre,
      pruebaObjetivo: '800 Libre',
      estado: EstadoPlan.publicado,
      versionMetodologia: '3.6.0',
      microciclos: const [
        Microciclo(
          id: 'm1',
          nombre: 'Semana 1',
          orden: 1,
          objetivo: 'Economía de nado',
        ),
      ],
      sesiones: [
        _sesion(id: 's1', fecha: _hoy),
        _sesion(id: 's2', fecha: _hoy.add(const Duration(days: 2))),
      ],
    );

EstadoNadador _estadoNadador() {
  final estado = EstadoNadador(
    sincronizador: Sincronizador(
      registros: _RegistrosEnMemoria(),
      bandeja: _BandejaEnMemoria(),
      red: _SinRed(),
      transporte: _TransporteQuieto(),
      reloj: () => _hoy,
    ),
    reloj: () => _hoy,
  );
  estado.abrirComo(
    const Nadador(id: 'n1', nombre: 'Juan Esteban Restrepo'),
    plan: _plan(),
  );
  return estado;
}

/// Las pantallas que se miden.
///
/// No están todas las de `lib/ui/`: están las que alguien abre y recorre. Los
/// paneles sueltos viajan dentro de ellas.
List<PantallaMedible> pantallasDeLaApp() => [
      PantallaMedible(
        'acceso',
        () => PantallaAcceso(
          alEnviar: ({
            required String correo,
            required String clave,
            required ModoDeAcceso modo,
          }) async =>
              null,
        ),
      ),
      PantallaMedible(
        'sesión del día',
        () => ChangeNotifierProvider<EstadoNadador>.value(
          value: _estadoNadador(),
          child: const PantallaSesionDelDia(),
        ),
      ),
      PantallaMedible(
        'mi progreso',
        () => ChangeNotifierProvider<EstadoNadador>.value(
          value: _estadoNadador(),
          child: const PantallaMiProgreso(),
        ),
      ),
      PantallaMedible(
        'perfiles',
        () => PantallaPerfiles(
          repositorio: RepositorioNadadoresMemoria()
            ..guardar(
              const Nadador(
                id: 'n1',
                nombre: 'Juan Esteban Restrepo',
                categoria: Categoria.precompetitivo,
                estiloObjetivo: Estilo.libre,
                pruebaObjetivo: '800 Libre',
              ),
            ),
        ),
      ),
      PantallaMedible(
        'editor de sesión',
        () => ChangeNotifierProvider<EstadoEditor>(
          create: (_) => EstadoEditor(biblioteca: _biblioteca())
            ..cambiarObjetivoTecnico('Técnica de eficiencia en Libre')
            ..escribirParte(TipoParte.inicial, "4x100 AL / 2'"),
          child: const PantallaEditor(),
        ),
      ),
      PantallaMedible(
        'petición de plan',
        () => PantallaPeticion(
          biblioteca: _biblioteca(),
          alGenerar: (_) {},
        ),
      ),
      PantallaMedible(
        'plan',
        () => PantallaPlan(
          plan: _plan(),
          versionMetodologia: '3.6.0',
          nadadores: const [
            Nadador(
              id: 'n1',
              nombre: 'Juan Esteban Restrepo',
              categoria: Categoria.precompetitivo,
              estiloObjetivo: Estilo.libre,
            ),
          ],
          conConsentimiento: const {'n1'},
        ),
      ),
    ];

// ---------------------------------------------------------------------------
// Dobles. Lo mínimo para que las pantallas se pinten.
// ---------------------------------------------------------------------------

class _RegistrosEnMemoria implements RepositorioRegistros {
  final Map<String, RegistroDeSesion> _guardados = {};

  @override
  Future<RegistroDeSesion?> obtener(String id) async => _guardados[id];

  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(String n, String p) async =>
      _guardados.values.toList();

  @override
  Future<void> guardar(RegistroDeSesion registro) async =>
      _guardados[registro.id] = registro;

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async => _guardados.clear();
}

class _BandejaEnMemoria implements BandejaDeSalida {
  final Map<String, EnvioPendiente> _envios = {};

  @override
  Future<void> encolar(String id) async =>
      _envios[id] = EnvioPendiente(registroId: id);

  @override
  Future<List<EnvioPendiente>> pendientes() async =>
      _envios.values.where((e) => e.esperaEnvio).toList();

  @override
  Future<EnvioPendiente?> estadoDe(String id) async => _envios[id];

  @override
  Future<void> actualizar(EnvioPendiente envio) async =>
      _envios[envio.registroId] = envio;
}

class _SinRed implements EstadoDeRed {
  @override
  Future<bool> hayConexion() async => false;

  @override
  Stream<bool> get cambios => const Stream<bool>.empty();
}

class _TransporteQuieto implements EnvioDeRegistros {
  @override
  Future<DateTime> enviar(RegistroDeSesion registro) async => _hoy;
}
