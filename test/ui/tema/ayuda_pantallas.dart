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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/memoria/repositorios_memoria.dart';
import 'package:natacion_app/datos/perfil/repositorio_perfil.dart';
import 'package:natacion_app/datos/recursos/recursos_iniciales.dart';
import 'package:natacion_app/dominio/consentimiento/consentimiento.dart';
import 'package:natacion_app/dominio/consentimiento/constancia.dart';
import 'package:natacion_app/dominio/datos_personales/derechos_del_titular.dart';
import 'package:natacion_app/ui/ajustes/pantalla_ajustes.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/cuentas/cuenta.dart';
import 'package:natacion_app/ui/hub/hub.dart';
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
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/pantalla_mi_progreso.dart';
import 'package:natacion_app/ui/nadador/mi_macrociclo.dart';
import 'package:natacion_app/ui/nadador/pantalla_sesion_del_dia.dart';
import 'package:natacion_app/ui/nadadores/pantalla_perfiles.dart';
import 'package:natacion_app/ui/peticion/estado_de_mi_peticion.dart';
import 'package:natacion_app/ui/peticion/peticion_del_nadador.dart';
import 'package:natacion_app/ui/planes/pantalla_plan.dart';
import 'package:natacion_app/dominio/macrociclo/derivar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/macrociclo/guardar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/ui/macrociclo/estructura.dart';
import 'package:natacion_app/ui/macrociclo/revisar_macrociclo.dart';
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

/// Lo que la app carga al arrancar, con los dobles de este banco.
///
/// Sin Firestore a propósito: la pantalla principal cae entonces en los
/// repositorios de memoria, que es lo que permite medirla sin servidor.
RecursosIniciales _recursos() => RecursosIniciales(
  biblioteca: _biblioteca(),
  versionMetodologia: '3.6.0',
  indiceTerminos: IndiceTerminos.vacio(),
  red: _SinRed(),
  transporte: _TransporteQuieto(),
);

/// Las pantallas que se miden.
///
/// No están todas las de `lib/ui/`: están las que alguien abre y recorre. Los
/// paneles sueltos viajan dentro de ellas.
List<PantallaMedible> pantallasDeLaApp() => [
  // **La pantalla que todo el mundo ve, y que nadie había medido.**
  //
  // `PantallaPrincipal` vivía en `main.dart`, fuera de `lib/ui/`, así que
  // el cerrojo A15 no la alcanzaba: la barra de pestañas no se había
  // comprobado ni al 200% de letra, ni en áreas pulsables, ni en oscuro.
  // Al mudarla a `lib/ui/hub/` en la feature 007, el cerrojo la encontró
  // en el primer `flutter test`.
  //
  // Se monta con los dos roles porque son dos disposiciones distintas: el
  // entrenador ve unos contenidos y el nadador otros, y medir solo uno
  // deja el otro sin medir.
  PantallaMedible(
    'hub — entrenador',
    () => PantallaPrincipal(
      recursos: _recursos(),
      cuenta: Cuenta(id: 'u1', rol: Rol.entrenador),
    ),
  ),
  PantallaMedible(
    'hub — nadador',
    () => PantallaPrincipal(
      recursos: _recursos(),
      cuenta: Cuenta(id: 'u2', rol: Rol.nadador, nadadorId: 'n1'),
    ),
  ),
  // La lista de seis preguntas de la feature 008. Se mide aparte del HUB
  // porque dentro de él solo aparece con servidor, y sin medirla nadie
  // comprueba que un nadador de nueve años pueda tocar sus chips al 200% de
  // letra. Ahí es donde vive SC-001.
  PantallaMedible(
    'petición — la lista de preguntas',
    () => PeticionDelNadador(
      nadadorId: 'n1',
      nadadores: _nadadores(),
      peticiones: _PeticionesDePrueba(),
      hoyParaPruebas: _hoy,
    ),
  ),
  PantallaMedible(
    'petición — en qué va la mía',
    () => EstadoDeMiPeticion(
      peticion: PeticionDePlan(
        nadadorId: 'n1',
        enviadaEn: _hoy,
        respuestas: RespuestasDePeticion(
          estiloObjetivo: Estilo.libre,
          pruebaObjetivo: '200 Libre',
          fechaDeCompetencia: _hoy.add(const Duration(days: 24)),
          diasDisponibles: [
            _hoy.add(const Duration(days: 1)),
            _hoy.add(const Duration(days: 3)),
          ],
          duracionSesionMinutos: 90,
          longitudPiscina: 25,
        ),
        estado: EstadoDePeticion.rechazada,
        // Un motivo de verdad, con la longitud que tendría uno de verdad: un
        // texto corto no mide el ajuste de línea que el real sí necesita.
        motivoDelRechazo:
            'Pediste cinco días y en Precompetitivo son tres. Te armo uno de '
            'tres y lo subimos cuando veamos cómo te sienta.',
        respondidaEn: _hoy.add(const Duration(days: 1)),
      ),
    ),
  ),
  PantallaMedible(
    'acceso',
    () => PantallaAcceso(
      alEnviar:
          ({
            required String correo,
            required String clave,
            required ModoDeAcceso modo,
          }) async => null,
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
    () => PantallaPeticion(biblioteca: _biblioteca(), alGenerar: (_) {}),
  ),
  PantallaMedible('alta — nombre', () => _alta(const Perfil())),
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
        terminos: AceptacionDeTerminos(version: 'v1', aceptadaEn: _hoy),
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
  // Ajustes, de la feature 007. Es la pantalla más larga de la app y la que
  // lleva los textos legales dentro, así que si algo desborda al 200%, es
  // aquí. Se monta con el perfil de una menor **con constancia de
  // consentimiento**, que es el caso con más contenido: el de un adulto no
  // tiene esa sección y la dejaría sin medir.
  PantallaMedible(
    'ajustes',
    () => PantallaAjustes(
      uid: 'u1',
      nadadorId: 'n1',
      repositorioPerfil: _PerfilDePrueba(),
      constancias: _ConstanciaDePrueba(),
      derechos: DerechosDelTitular(
        nadadores: RepositorioNadadoresMemoria(),
        registros: _RegistrosEnMemoria(),
        asignaciones: RepositorioAsignacionesMemoria(),
      ),
    ),
  ),

  // Las dos pantallas del macrociclo (feature 009).
  //
  // **Montadas con contenido, no vacías.** La de estructura se abre con la
  // fecha puesta para que el banco mida los tres bloques editables con sus
  // razones, que es donde está el contenido largo: «Acumulación, las primeras
  // 8 semanas: es la base, y se queda con lo que no es transformación ni
  // afinación» al 200% de letra en un teléfono de 360 puntos.
  //
  // Montarla sin fecha habría medido una tarjeta y dos frases, y la 005 ya
  // enseñó lo que eso cuesta: con un plan sin fase ATR, media pantalla del
  // plan no se pintaba en ninguna prueba, y al añadir la fase aparecieron dos
  // desbordes que llevaban ahí desde la feature 002.
  PantallaMedible(
    'macrociclo — estructura',
    () => PantallaEstructura(
      ficha: _nadadorDePrueba,
      biblioteca: _biblioteca(),
      versionMetodologia: '3.6.0',
      hoy: _hoy,
      competenciaInicial: _hoy.add(const Duration(days: 97)),
      planes: RepositorioPlanesMemoria(),

      macrociclos: RepositorioMacrociclosMemoria(),
      alConfirmar: (_) {},
    ),
  ),
  // El `Ver Plan` del nadador, con un macrociclo de catorce semanas entregado
  // y algunas sesiones ya marcadas.
  //
  // **Es la pantalla más larga de la app** y la que más controles de plegado
  // lleva: catorce semanas, cuarenta y dos sesiones, cada una con su
  // `ExpansionTile`. Si uno de esos controles no alcanza el área pulsable al
  // 200% de letra, el contenido es alcanzable en teoría y no en la práctica
  // (M22). Y la lista de pendientes crece con lo que el nadador no marcó, así
  // que se monta con dos sin marcar para que ese aviso también se mida.
  PantallaMedible(
    'macrociclo — el del nadador',
    () => PantallaMiMacrociclo(
      nadadorId: 'n1',
      macrociclos: _MacrociclosDelBanco(),
      planes: _PlanesDelBanco(),
      registros: _RegistrosDelBanco(),
      // Dentro del segundo mesociclo, con sesiones pasadas sin marcar.
      hoy: _hoy.add(const Duration(days: 60)),
      sinMacrociclo: const SizedBox.shrink(),
    ),
  ),
  PantallaMedible(
    'macrociclo — revisar',
    () => PantallaRevisarMacrociclo(
      guardado: _macrocicloParaElBanco(),
      hoy: _hoy,
      planes: RepositorioPlanesMemoria(),
      asignaciones: RepositorioAsignacionesMemoria(),
      macrociclos: RepositorioMacrociclosMemoria(),
    ),
  ),
];

/// La ficha con la que se mide: completa y con anotaciones del entrenador, que
/// es el caso con más texto en los dos modelos.
const Nadador _nadadorDePrueba = Nadador(
  id: 'n1',
  nombre: 'Ana María Restrepo Vélez',
  categoria: Categoria.precompetitivo,
  estiloObjetivo: Estilo.libre,
  pruebaObjetivo: '200 Libre',
  diagnosticoTecnico: [
    'pierde el agarre al fatigarse',
    'respiración tardía en el segundo 50',
  ],
);

/// Un macrociclo derivado de verdad, para medir la pantalla de revisión.
///
/// Se construye sin tocar repositorios: `derivarMacrociclo` es síncrono y puro,
/// y `MacrocicloGuardado` es un objeto de valor. El banco necesita
/// constructores síncronos, así que los identificadores se ponen a mano — es
/// lo único que el almacenamiento habría añadido.
MacrocicloGuardado _macrocicloParaElBanco() {
  final competencia = _hoy.add(const Duration(days: 97));

  final propuesto = esqueletoParaMacrociclo(
    fechaDeCompetencia: competencia,
    hoy: _hoy,
    categoria: Categoria.precompetitivo,
  );

  final derivado =
      derivarMacrociclo(
            estructura: EstructuraConfirmada(
              modeloDeLaPrueba:
                  '200 libre: umbral alto sostenido, viraje rápido y los '
                  'últimos 25 sin perder la frecuencia.',
              modeloDelNadador:
                  'Crol dominante, pierde el agarre al fatigarse, recupera '
                  'bien entre series y responde a los retos cortos.',
              bloques: propuesto.bloques,
              confirmadaEn: _hoy,
              diasPorSemana: const [1, 3, 5],
              duracionSesionMinutos: 90,
              longitudPiscina: 25,
            ),
            ficha: _nadadorDePrueba,
            biblioteca: _biblioteca(),
            versionMetodologia: '3.6.0',
            nombre: 'Hacia el Departamental de fin de año',
            fechaDeCompetencia: competencia,
          )
          as MacrocicloDerivado;

  const ids = ['p1', 'p2', 'p3'];

  return MacrocicloGuardado(
    macrociclo: derivado.macrocicloConLosIds(ids).copiarCon(id: 'macro-1'),
    mesociclos: [
      for (var i = 0; i < derivado.mesociclos.length; i++)
        derivado.mesociclos[i].copiarCon(
          id: ids[i],
          macrocicloId: 'macro-1',
        ),
    ],
  );
}

class _PerfilDePrueba implements RepositorioPerfil {
  @override
  Future<Perfil> obtener(String uid) async => Perfil(
    nombre: 'Ana María Restrepo Vélez',
    fechaNacimiento: DateTime(2014, 3, 7),
    pais: 'CO',
    terminos: AceptacionDeTerminos(version: 'v1', aceptadaEn: _hoy),
  );
}

class _ConstanciaDePrueba implements LectorDeConstancias {
  @override
  Future<ConstanciaDeConsentimiento?> de(String nadadorId) async =>
      ConstanciaDeConsentimiento(
        vigente: true,
        alcances: const {Alcance.datosDeEntrenamiento},
        versionDelTexto: 'v1',
        otorgadoEn: _hoy,
      );
}

// ---------------------------------------------------------------------------
// Dobles. Lo mínimo para que las pantallas se pinten.
// ---------------------------------------------------------------------------

/// El macrociclo del banco, ya entregado y con identificadores.
///
/// Los tres dobles de abajo responden **al instante y sin `Future` pendiente**:
/// el banco monta las pantallas con dos bombeos, y un doble que tardara dejaría
/// la pantalla midiendo su `CircularProgressIndicator` en lugar de su
/// contenido. Eso es la trampa que la feature 005 documenta: un banco que mide
/// un `Column` de juguete siempre pasa.
MacrocicloGuardado _entregadoParaElBanco() {
  final guardado = _macrocicloParaElBanco();

  return MacrocicloGuardado(
    macrociclo: guardado.macrociclo.copiarCon(estado: EstadoPlan.publicado),
    mesociclos: [
      for (final mesociclo in guardado.mesociclos)
        mesociclo.copiarCon(estado: EstadoPlan.publicado),
    ],
  );
}

class _MacrociclosDelBanco implements RepositorioMacrociclos {
  @override
  Future<List<Macrociclo>> deNadador(String nadadorId) async => [
    _entregadoParaElBanco().macrociclo,
  ];

  @override
  Future<Macrociclo?> obtener(String id) async =>
      _entregadoParaElBanco().macrociclo;

  @override
  Future<String> guardarBorrador(Macrociclo macrociclo) async => 'macro-1';

  @override
  Future<void> guardarAprobado(Macrociclo m, Map<String, dynamic> a) async {}

  @override
  Future<void> publicar(String id) async {}

  @override
  Future<void> anunciarElReajuste(
    String id, {
    required List<String> mesociclos,
    required ReajusteAnunciado aviso,
  }) async {}

  @override
  Future<Map<String, dynamic>> exportar(String id) async => {};
}

class _PlanesDelBanco implements RepositorioPlanes {
  @override
  Future<Plan?> obtener(String id) async {
    for (final mesociclo in _entregadoParaElBanco().mesociclos) {
      if (mesociclo.id == id) return mesociclo;
    }
    return null;
  }

  @override
  Future<List<Plan>> listar({Categoria? categoria, EstadoPlan? estado}) async =>
      _entregadoParaElBanco().mesociclos;

  @override
  Future<String> guardarBorrador(Plan plan) async => plan.id ?? 'p1';

  @override
  Future<void> guardarAprobado(Plan p, Map<String, dynamic> a) async {}

  @override
  Future<void> publicar(String id) async {}

  @override
  Future<Plan> crearVersionDesde(String id) async =>
      _entregadoParaElBanco().mesociclos.first;

  @override
  Future<Map<String, dynamic>> exportar(String id) async => {};
}

/// Dos sesiones marcadas del primer mesociclo, para que la portada enseñe una
/// adherencia de verdad y la lista de pendientes no llegue vacía.
class _RegistrosDelBanco implements RepositorioRegistros {
  @override
  Future<List<RegistroDeSesion>> obtenerDePlan(
    String nadadorId,
    String planId,
  ) async {
    if (planId != 'p1') return const [];

    final sesiones = _entregadoParaElBanco().mesociclos.first.sesiones;
    return [
      for (final sesion in sesiones.take(2))
        RegistroDeSesion(
          nadadorId: nadadorId,
          planId: planId,
          sesionId: sesion.id ?? '',
          versionDePlan: '3.6.0',
          realizada: true,
          registradoEn: _hoy,
          rpePercibido: 6,
          observaciones: 'Me costó el último 100, pero lo saqué.',
        ),
    ];
  }

  @override
  Future<RegistroDeSesion?> obtener(String id) async => null;

  @override
  Future<void> guardar(RegistroDeSesion registro) async {}

  @override
  Future<Map<String, dynamic>> exportar(String nadadorId) async => {};

  @override
  Future<void> eliminarDe(String nadadorId) async {}

  @override
  Future<Set<String>> nadadoresConRegistros() async => {'n1'};
}

class _RegistrosEnMemoria implements RepositorioRegistros {
  @override
  Future<Set<String>> nadadoresConRegistros() async =>
      _guardados.values.map((r) => r.nadadorId).toSet();

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

/// La ficha con la que se mide la lista de preguntas. Completa: sin categoría
/// la pantalla enseñaría el aviso en lugar de las seis preguntas, y mediríamos
/// un cartel.
RepositorioNadadores _nadadores() {
  final repositorio = RepositorioNadadoresMemoria();
  unawaited(
    repositorio.guardar(
      const Nadador(
        id: 'n1',
        nombre: 'Juan Esteban Restrepo',
        categoria: Categoria.precompetitivo,
        estiloObjetivo: Estilo.libre,
        pruebaObjetivo: '200 Libre',
      ),
    ),
  );
  return repositorio;
}

/// Sin petición mandada, para que lo que se mida sea la lista.
class _PeticionesDePrueba implements RepositorioPeticiones {
  @override
  Future<PeticionDePlan?> miPeticion(String nadadorId) async => null;

  @override
  Future<List<PeticionDePlan>> cola() async => const [];

  @override
  Future<void> enviar({
    required String nadadorId,
    required RespuestasDePeticion respuestas,
  }) async {}

  @override
  Future<void> marcarEnRevision(String nadadorId) async {}
}
