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
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/metodologia/zonas.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/dominio/sincronizacion/bandeja_salida.dart';
import 'package:natacion_app/ui/acceso/pantalla_acceso.dart';
import 'package:natacion_app/dominio/cuentas/perfil.dart';
import 'package:natacion_app/ui/alta/estado_alta.dart';
import 'package:natacion_app/ui/alta/pantalla_alta.dart';
import 'package:natacion_app/ui/consentimiento/pantalla_confirmacion.dart';
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
      // **Con fase ATR a propósito.** Sin ella, `repartoPorZona` devuelve una
      // lista vacía y las siete filas de zonas —con su rampa de color— no se
      // pintan en ninguna prueba. El banco mediría una pantalla a la que le
      // falta justo lo que la fase 6 añadió.
      faseAtr: FaseAtr.acumulacion,
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

/// El alta, montada en el paso que se quiera mirar.
///
/// Los pasos del alta son pantallas distintas aunque compartan contenedor, y
/// medir solo el primero dejaría los otros cuatro sin medir — que es
/// exactamente el fallo que la feature 005 cometió dos veces.
Widget _alta(Perfil perfil, {int paso = 0}) {
  final estado = EstadoAlta(
    operaciones: null,
    correoDeLaCuenta: 'nadador@ejemplo.com',
    reloj: () => _hoy,
  );

  if (perfil.nombre.isNotEmpty) estado.escribirNombre(perfil.nombre);
  if (perfil.fechaNacimiento != null) {
    estado.escribirNacimiento(perfil.fechaNacimiento);
  }
  if (perfil.pais != null) estado.escribirPais(perfil.pais);
  if (perfil.terminos != null) estado.aceptarTerminos(aceptados: true);

  for (var i = 0; i < paso; i++) {
    estado.avanzar();
  }

  return ChangeNotifierProvider<EstadoAlta>.value(
    value: estado,
    child: PantallaAlta(alTerminar: (_) {}),
  );
}

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
        'alta — nombre',
        () => _alta(const Perfil()),
      ),
      PantallaMedible(
        'alta — términos',
        // El paso de los términos lleva el texto legal entero dentro, que es
        // el contenido más largo de toda la app. Si algo desborda, es aquí.
        () => _alta(
          Perfil(
            nombre: 'Juan Esteban Restrepo',
            fechaNacimiento: DateTime(1995, 4, 12),
            pais: 'CO',
          ),
          paso: 3,
        ),
      ),
      PantallaMedible(
        'alta — acudiente',
        // Solo aparece para menores, así que el perfil lleva una fecha de
        // menor a propósito: con una de adulto, este paso no existiría y la
        // pantalla no se mediría.
        () => _alta(
          Perfil(
            nombre: 'Ana María Restrepo',
            fechaNacimiento: DateTime(2014, 3, 10),
            pais: 'CO',
            terminos: AceptacionDeTerminos(
              version: 'v1',
              aceptadaEn: _hoy,
            ),
          ),
          paso: 4,
        ),
      ),
      PantallaMedible(
        'confirmación del acudiente',
        // La añadió la feature 006, y la encontró el cerrojo A15: llevaba
        // desde la 004 **sin que nadie la midiera**. Es la pantalla que un
        // acudiente abre en su teléfono para autorizar los datos de su hijo, y
        // nadie había comprobado que se lea con la letra grande.
        //
        // El texto informativo va largo a propósito: es lo que de verdad lleva
        // dentro, y un texto corto nunca desborda.
        () => PantallaConfirmacion(
          versionDelTexto: 'v1',
          textoInformativo:
              'Tratamiento de datos personales de menores de edad. '
              'La información que registra su hijo o hija —asistencia a las '
              'sesiones, esfuerzo percibido y molestias— se usa únicamente '
              'para que su entrenador ajuste el entrenamiento. No se comparte '
              'con terceros, no se usa con fines publicitarios y no se emplea '
              'para entrenar modelos. Puede retirar esta autorización cuando '
              'quiera, desde este mismo enlace y sin pasar por el entrenador.',
          alConfirmar: (_) async => null,
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
