/// `Ver Plan` del nadador: el camino completo desde el primer día.
///
/// **Todo visible, plegado** (aclaración Q2, M18 a M23). La estructura va
/// desplegada —mesociclos, nombres, objetivos, fechas— y **cualquier** sesión
/// se abre de un toque, incluso una de dentro de seis semanas. No se esconde
/// nada y no se le echa todo encima de golpe a un niño de nueve años.
///
/// Y el coste, dicho claro: **una lista plegada de setenta sesiones sigue
/// siendo larga.** Por eso la vista se abre **en el día de hoy** y no en la
/// semana uno (M19), y por eso los controles de plegado se miden al 200% de
/// letra y en área pulsable como todo lo demás desde la feature 005: un
/// control que un niño de nueve años no puede tocar hace el contenido
/// alcanzable en teoría y no en la práctica (M22).
///
/// **Sin macrociclo enseña lo que la feature 003 le dio** (M23). Una jerarquía
/// vacía sería peor que su sesión de hoy.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';
import 'package:natacion_app/dominio/entidades/registro_sesion.dart';
import 'package:natacion_app/dominio/entidades/sesion.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/registros_del_linaje.dart';
import 'package:natacion_app/dominio/macrociclo/progreso_en_el_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/puede_marcarse.dart';
import 'package:natacion_app/ui/nadador/estado_nadador.dart';
import 'package:natacion_app/ui/nadador/formulario_registro.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

class PantallaMiMacrociclo extends StatefulWidget {
  const PantallaMiMacrociclo({
    super.key,
    required this.nadadorId,
    required this.macrociclos,
    required this.planes,
    required this.registros,
    required this.hoy,
    required this.sinMacrociclo,
    this.estado,
  });

  /// Para que el nadador pueda marcar desde aquí (M24 a M28).
  ///
  /// Nulo cuando no hay con qué guardar —el banco de pantallas, por ejemplo—:
  /// entonces una sesión desplegada enseña lo que lleva dentro y nada más. Lo
  /// que no hace es ofrecer un control que no guarda nada.
  final EstadoNadador? estado;

  final String nadadorId;
  final RepositorioMacrociclos macrociclos;
  final RepositorioPlanes planes;
  final RepositorioRegistros registros;
  final DateTime hoy;

  /// Lo que se le enseña cuando no tiene macrociclo: su sesión de hoy, que es
  /// lo que la feature 003 le dio. **No una jerarquía vacía** (M23).
  final Widget sinMacrociclo;

  @override
  State<PantallaMiMacrociclo> createState() => _PantallaMiMacrocicloState();
}

class _PantallaMiMacrocicloState extends State<PantallaMiMacrociclo> {
  Macrociclo? _macrociclo;
  List<Plan> _mesociclos = const [];
  List<RegistroDeSesion> _registros = const [];

  bool _cargando = true;
  String? _problema;

  /// Dónde está la sesión de hoy, para abrir ahí (M19).
  final GlobalKey _dondeEstaHoy = GlobalKey();

  @override
  void initState() {
    super.initState();
    _cargar();

    // **Escuchar a quien ya avisa.** `EstadoNadador` es un `ChangeNotifier` y
    // llama a `notifyListeners` cada vez que el nadador responde algo; esta
    // pantalla leía los registros una sola vez aquí y nadie la despertaba.
    //
    // Así se veía en el Pixel 7: Ana marcaba su sesión, el registro se
    // guardaba —estaba en Firestore, con su esfuerzo— y la pantalla seguía
    // diciendo «Sesiones cumplidas: 0 de 24». Para ella eso no es un refresco
    // que falta, es que marcar no funcionó, así que vuelve a tocar el botón.
    widget.estado?.addListener(_algoSeRespondio);
  }

  @override
  void didUpdateWidget(PantallaMiMacrociclo anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.estado != widget.estado) {
      anterior.estado?.removeListener(_algoSeRespondio);
      widget.estado?.addListener(_algoSeRespondio);
    }
  }

  @override
  void dispose() {
    widget.estado?.removeListener(_algoSeRespondio);
    super.dispose();
  }

  /// Vuelve a leer **solo los registros**, que es lo único que pudo cambiar.
  ///
  /// Ni el macrociclo ni los mesociclos: el nadador no los toca, y releerlos
  /// costaría una consulta por bloque cada vez que responde algo.
  Future<void> _algoSeRespondio() async {
    final mesociclos = _mesociclos;
    if (mesociclos.isEmpty) return;

    final registros = await _loQueAnoto(mesociclos);

    if (!mounted) return;
    setState(() => _registros = registros);
  }

  /// Lo que el nadador anotó, **siguiendo el linaje de versiones**.
  ///
  /// Un reajuste crea una versión nueva del mesociclo: un plan nuevo, con
  /// identificador nuevo. Los registros apuntan al plan en el que se
  /// escribieron, así que leer solo los mesociclos actuales encuentra cero.
  ///
  /// Esto se vio en el Pixel 7, y es lo peor que ha dado esta feature porque
  /// la app se contradice en la misma pantalla: arriba «Lo que ya habías
  /// anotado sigue ahí» y debajo «Sesiones cumplidas: 0 de 24», con las dos
  /// que acababa de marcar listadas como pendientes.
  ///
  /// `registrosDelLinaje` existe para exactamente esto, con sus pruebas desde
  /// que se escribió, y **nadie lo llamaba**. Estaba hecho y sin conectar.
  Future<List<RegistroDeSesion>> _loQueAnoto(List<Plan> mesociclos) async {
    final registros = <RegistroDeSesion>[];

    for (final mesociclo in mesociclos) {
      if (mesociclo.id == null) continue;
      registros.addAll(
        await registrosDelLinaje(
          mesociclo: mesociclo,
          nadadorId: widget.nadadorId,
          registros: widget.registros,
          planes: widget.planes,
        ),
      );
    }

    return registros;
  }

  Future<void> _cargar() async {
    try {
      final suyos = await widget.macrociclos.deNadador(widget.nadadorId);

      // **Solo lo entregado.** Un borrador o un aprobado sin entregar no es
      // suyo todavía: firmar no es entregar, y las reglas lo comprueban
      // aparte.
      final entregado = suyos
          .where((m) => m.estado == EstadoPlan.publicado)
          .firstOrNull;

      if (entregado == null) {
        if (!mounted) return;
        setState(() {
          _macrociclo = null;
          _cargando = false;
        });
        return;
      }

      final mesociclos = <Plan>[];
      for (final id in entregado.mesociclos) {
        final plan = await widget.planes.obtener(id);
        if (plan != null) mesociclos.add(plan);
      }

      final registros = await _loQueAnoto(mesociclos);

      if (!mounted) return;
      setState(() {
        _macrociclo = entregado;
        _mesociclos = mesociclos;
        _registros = registros;
        _cargando = false;
      });

      _abrirEnHoy();
    } on Object catch (problema) {
      if (!mounted) return;
      setState(() {
        _problema = problema.toString();
        _cargando = false;
      });
    }
  }

  /// Deja la vista puesta en hoy, no en la semana uno (M19, FR-021).
  ///
  /// **Solo si hoy no se ve ya.** Desplazar siempre le tira la portada fuera
  /// de la pantalla, y en la portada está lo que M20 y M21 prometen: por qué
  /// bloque va, cuántas lleva cumplidas y que el plan puede cambiar. Lo
  /// encontró la prueba de widget en el primer intento: el día uno la sesión
  /// de hoy es de las primeras, la vista saltaba a ella de todas formas y
  /// `donde-voy` desaparecía del árbol.
  ///
  /// Así que la regla es la que el nadador necesita y no la que es más fácil
  /// de escribir: en la primera semana no se mueve nada, y en la décima se
  /// coloca en su sesión.
  void _abrirEnHoy() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final donde = _dondeEstaHoy.currentContext;
      if (donde == null || !mounted) return;

      final render = donde.findRenderObject();
      final posicion = Scrollable.maybeOf(donde)?.position;

      if (render != null && posicion != null && posicion.hasViewportDimension) {
        final arriba = RenderAbstractViewport.of(
          render,
        ).getOffsetToReveal(render, 0).offset;

        // Un margen para no dejarla pegada al borde de abajo.
        const margen = 120.0;
        final yaSeVe =
            arriba >= posicion.pixels &&
            arriba <= posicion.pixels + posicion.viewportDimension - margen;

        if (yaSeVe) return;
      }

      Scrollable.ensureVisible(
        donde,
        alignment: 0.1,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  ProgresoEnElMacrociclo get _progreso => ProgresoEnElMacrociclo(
    mesociclos: _mesociclos,
    registros: _registros,
    hoy: widget.hoy,
  );

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_problema != null) {
      return Padding(
        padding: const EdgeInsets.all(Espaciado.amplio),
        child: Aviso(
          tono: TonoDeAviso.error,
          mensaje: 'No se pudo cargar tu plan: $_problema',
          claveDelMensaje: const Key('no-se-pudo-cargar-el-macrociclo'),
        ),
      );
    }

    // M23: sin macrociclo, lo que la feature 003 le dio.
    if (_macrociclo == null) {
      return KeyedSubtree(
        key: const Key('sin-macrociclo-la-sesion-de-hoy'),
        child: widget.sinMacrociclo,
      );
    }

    final progreso = _progreso;
    final texto = Theme.of(context).textTheme;

    // **La portada va fija y no dentro de la lista.**
    //
    // Si va dentro, el desplazamiento a hoy se la lleva por delante, y con
    // ella lo que M20 y M21 prometen: por qué bloque va y que el plan puede
    // cambiar. Lo encontró la prueba de widget: el día uno la sesión de hoy
    // cae justo bajo el pliegue en un teléfono de 360, la vista bajaba a ella
    // y `donde-voy` desaparecía del árbol.
    //
    // M19 y M20 no están en conflicto; lo estaba la forma de pintarlos. Lo que
    // el nadador necesita siempre delante son dos líneas, y lo que se recorre
    // es el camino.
    return Column(
      key: const Key('mi-macrociclo'),
      children: [
        // **Fijo: dos líneas y nada más.**
        //
        // Lo primero que puse fijo fue la portada entera más el aviso
        // completo, y el banco de la feature 005 lo tumbó: al 200% de letra
        // eso no cabe en un teléfono de 360 por 640, y lo que sobraba se salía
        // por abajo —6746 píxeles, porque al no quedar sitio para la parte
        // desplazable el camino entero intentaba pintarse.
        //
        // Así que fijo va lo que el nadador necesita tener delante siempre, y
        // son dos frases cortas: por dónde va (M20) y que el plan puede
        // cambiar (M21). El nombre, las cumplidas y la fecha se desplazan con
        // el resto.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaciado.amplio,
            Espaciado.normal,
            Espaciado.amplio,
            Espaciado.corto,
          ),
          child: _DondeVoy(progreso: progreso),
        ),
        Expanded(child: _elCamino(context, progreso, texto)),
      ],
    );
  }

  Widget _elCamino(
    BuildContext context,
    ProgresoEnElMacrociclo progreso,
    TextTheme texto,
  ) {
    // **Un `SingleChildScrollView` y no un `ListView`, a propósito.**
    //
    // `Scrollable.ensureVisible` necesita que la sesión de hoy **exista en el
    // árbol**, y una lista perezosa no construye lo que está cuarenta filas más
    // abajo. En la semana diez la sesión de hoy no se construye nunca, la
    // llamada a desplazar no encuentra a dónde ir, y el nadador aterriza en la
    // semana uno: exactamente lo que M19 prohíbe, **y sin que nada falle**.
    //
    // Lo encontró la prueba de widget de M19. El primer intento de arreglarlo
    // fue un `cacheExtent` enorme, y no sirvió: con el aviso de pendientes
    // llenando la ventana, la lista seguía construyendo dos hijos y parando.
    //
    // Un macrociclo son unas decenas de filas plegadas, así que construirlas
    // todas es barato, y es lo único que hace que «abrirse en hoy» funcione de
    // verdad. Si algún día un macrociclo tuviera cientos de sesiones habría
    // que cambiarlo por una lista indexada —y haría falta otra prueba, porque
    // este fallo no avisa.
    return SingleChildScrollView(
      key: const Key('el-camino'),
      padding: const EdgeInsets.all(Espaciado.amplio),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Portada(macrociclo: _macrociclo!, progreso: progreso),

          // FR-034, M32: ve que su entrenador ajustó esa parte, **sin tener
          // que comparar versiones**. Una frase, no un diff.
          if (_macrociclo!.ultimoReajuste != null) ...[
            const SizedBox(height: Espaciado.normal),
            Aviso(
              tono: TonoDeAviso.informativo,
              titulo: 'Tu entrenador ajustó tu plan',
              mensaje: _macrociclo!.ultimoReajuste!.comoSeLeElNadador,
              claveDelMensaje: const Key('tu-entrenador-ajusto'),
              detalles: const [
                LineaDeAviso(
                  icono: Icons.info_outline,
                  texto:
                      'Lo que ya habías anotado sigue ahí: esto cambia lo que '
                      'viene, no lo que hiciste.',
                ),
              ],
            ),
          ],

          if (progreso.pendientes.isNotEmpty) ...[
            const SizedBox(height: Espaciado.normal),
            _LoQuePendiente(pendientes: progreso.pendientes),
          ],

          if (progreso.yaTermino) ...[
            const SizedBox(height: Espaciado.normal),
            Aviso(
              tono: TonoDeAviso.exito,
              titulo: 'Terminaste el ciclo',
              mensaje:
                  'Llegaste a la última sesión de este macrociclo. El '
                  'siguiente lo prepara tu entrenador.',
              claveDelMensaje: const Key('ya-termino-el-ciclo'),
            ),
          ],

          const SizedBox(height: Espaciado.seccion),
          CabeceraSeccion(
            titulo: 'Tu camino',
            icono: Icons.route_outlined,
            cifra: '${_mesociclos.length} bloques',
          ),
          const SizedBox(height: Espaciado.corto),
          Text(
            'Está todo aquí. Toca una sesión para ver qué tiene, aunque sea de '
            'dentro de un mes.',
            style: texto.bodyMedium,
          ),
          const SizedBox(height: Espaciado.normal),

          for (var i = 0; i < _mesociclos.length; i++)
            _Mesociclo(
              key: ValueKey('mi-mesociclo-$i'),
              indice: i,
              plan: _mesociclos[i],
              esElActual: _mesociclos[i].id == progreso.mesocicloActual?.id,
              progreso: progreso,
              hoy: widget.hoy,
              claveDeHoy: _dondeEstaHoy,
              estado: widget.estado,
            ),

          const SizedBox(height: Espaciado.generoso),
        ],
      ),
    );
  }
}

/// Las dos frases que van siempre delante: por dónde va y que puede cambiar.
///
/// Cortas a propósito: esto está fijo, y lo fijo tiene que caber al 200% de
/// letra en un teléfono de 360 por 640. El banco de la feature 005 lo mide.
class _DondeVoy extends StatelessWidget {
  const _DondeVoy({required this.progreso});

  final ProgresoEnElMacrociclo progreso;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final actual = progreso.mesocicloActual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // M20, FR-017: dónde cae hoy y qué bloque está trabajando.
        Text(
          actual != null
              ? 'Vas por el bloque ${progreso.comoSeLee}'
              : !progreso.yaEmpezo
              ? 'Tu plan empieza pronto'
              : 'Terminaste este ciclo',
          key: const Key('donde-voy'),
          style: texto.titleMedium,
        ),
        // M21, FR-018: puede cambiar, en español y sin jerga.
        Text(
          'Tu plan puede cambiar según cómo vayas respondiendo.',
          key: const Key('puede-cambiar'),
          style: texto.bodySmall,
        ),
      ],
    );
  }
}

class _Portada extends StatelessWidget {
  const _Portada({required this.macrociclo, required this.progreso});

  final Macrociclo macrociclo;
  final ProgresoEnElMacrociclo progreso;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final actual = progreso.mesocicloActual;

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(macrociclo.nombre, style: texto.titleLarge),
          const SizedBox(height: Espaciado.corto),

          if (actual != null) Text(actual.nombre, style: texto.bodyLarge),
          const SizedBox(height: Espaciado.corto),
          Text(
            'Sesiones cumplidas: ${progreso.adherencia.descripcion}',
            key: const Key('cuantas-cumplidas'),
            style: texto.bodyMedium,
          ),
          Text(
            'Tu competencia es el '
            '${macrociclo.fechaDeCompetencia.day}/'
            '${macrociclo.fechaDeCompetencia.month}/'
            '${macrociclo.fechaDeCompetencia.year}',
            style: texto.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Lo que quedó atrás. **Se dice, no se bloquea** (M26, decisión D6).
class _LoQuePendiente extends StatelessWidget {
  const _LoQuePendiente({required this.pendientes});

  final List<Sesion> pendientes;

  @override
  Widget build(BuildContext context) {
    return Aviso(
      tono: TonoDeAviso.cuidado,
      titulo: pendientes.length == 1
          ? 'Te quedó una sesión por marcar'
          : 'Te quedaron ${pendientes.length} sesiones por marcar',
      mensaje:
          'No pasa nada: las puedes marcar cuando quieras. Se lo decimos para '
          'que tu entrenador vea cómo vas de verdad.',
      claveDelMensaje: const Key('lo-que-quedo-pendiente'),
      detalles: [
        for (final sesion in pendientes.take(5))
          LineaDeAviso(
            icono: Icons.schedule_outlined,
            texto:
                'La del ${sesion.fecha!.day}/${sesion.fecha!.month}'
                '${sesion.objetivoTecnico.isEmpty ? '' : ': ${sesion.objetivoTecnico}'}',
          ),
        if (pendientes.length > 5)
          LineaDeAviso(
            icono: Icons.more_horiz,
            texto: 'y ${pendientes.length - 5} más',
          ),
      ],
    );
  }
}

/// Un mesociclo, desplegado, con sus semanas y sus sesiones plegadas.
class _Mesociclo extends StatelessWidget {
  const _Mesociclo({
    super.key,
    required this.indice,
    required this.plan,
    required this.esElActual,
    required this.progreso,
    required this.hoy,
    required this.claveDeHoy,
    required this.estado,
  });

  final int indice;
  final Plan plan;
  final bool esElActual;
  final ProgresoEnElMacrociclo progreso;
  final DateTime hoy;
  final GlobalKey claveDeHoy;
  final EstadoNadador? estado;

  bool _esDeHoy(Sesion sesion) {
    final fecha = sesion.fecha;
    if (fecha == null) return false;
    return fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
  }

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Espaciado.normal),
      child: Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    plan.nombre,
                    key: Key('nombre-mesociclo-$indice'),
                    style: texto.titleMedium,
                  ),
                ),
                if (esElActual) ...[
                  const SizedBox(width: Espaciado.corto),
                  Container(
                    key: const Key('aqui-vas'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Espaciado.corto,
                      vertical: Espaciado.minimo,
                    ),
                    decoration: BoxDecoration(
                      color: colores.primaryContainer,
                      borderRadius: BorderRadius.circular(Espaciado.radioCorto),
                    ),
                    child: Text(
                      'Aquí vas',
                      style: texto.labelMedium?.copyWith(
                        color: colores.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (plan.fechaInicio != null && plan.fechaFin != null)
              Text(
                'Del ${plan.fechaInicio!.day}/${plan.fechaInicio!.month} al '
                '${plan.fechaFin!.day}/${plan.fechaFin!.month} · '
                '${progreso.adherenciaPorMesociclo[plan.id]?.descripcion ?? ''} '
                'sesiones',
                style: texto.bodySmall,
              ),
            const SizedBox(height: Espaciado.normal),

            // Las semanas, desplegadas. Lo que se pliega son las sesiones.
            for (final microciclo in plan.microciclos) ...[
              Text(microciclo.nombre, style: texto.titleSmall),
              if (microciclo.objetivo.isNotEmpty)
                Text(microciclo.objetivo, style: texto.bodySmall),
              const SizedBox(height: Espaciado.corto),
              for (final sesion in plan.sesionesDe(microciclo.id))
                _SesionPlegada(
                  key: _esDeHoy(sesion) ? claveDeHoy : null,
                  sesion: sesion,
                  esDeHoy: _esDeHoy(sesion),
                  estaHecha:
                      sesion.id != null && progreso.hechas.contains(sesion.id),
                  estado: estado,
                  mesociclo: plan,
                  hoy: hoy,
                ),
              const SizedBox(height: Espaciado.normal),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una sesión plegada que se abre de un toque. **Cualquiera de ellas** (M18).
class _SesionPlegada extends StatelessWidget {
  const _SesionPlegada({
    super.key,
    required this.sesion,
    required this.esDeHoy,
    required this.estaHecha,
    required this.estado,
    required this.mesociclo,
    required this.hoy,
  });

  final Sesion sesion;
  final bool esDeHoy;
  final bool estaHecha;

  /// Nulo cuando no hay con qué guardar: entonces la sesión se abre y enseña
  /// lo que lleva, sin ofrecer un control que no guarda nada (H12).
  final EstadoNadador? estado;

  /// A qué mesociclo pertenece, para que el registro apunte a ese y no al
  /// plan que estuviera abierto.
  final Plan mesociclo;

  /// Para la regla de la fecha.
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final fecha = sesion.fecha;

    return ExpansionTile(
      key: Key('sesion-${sesion.id ?? 'sin-id'}'),
      // El control de desplegar tiene que alcanzar el área mínima al 200% de
      // letra: lo mide el banco de la feature 005 (M22).
      tilePadding: const EdgeInsets.symmetric(horizontal: Espaciado.corto),
      minTileHeight: Espaciado.areaPulsableMinima,
      leading: Icon(
        estaHecha
            ? Icons.check_circle
            : esDeHoy
            ? Icons.today_outlined
            : Icons.circle_outlined,
      ),
      title: Text(
        fecha == null
            ? 'Sesión sin día asignado'
            : '${_diaDeLaSemana(fecha)} ${fecha.day}/${fecha.month}'
                  '${esDeHoy ? ' · hoy' : ''}',
        style: esDeHoy ? texto.titleSmall : texto.bodyMedium,
      ),
      subtitle: sesion.objetivoTecnico.isEmpty
          ? null
          : Text(sesion.objetivoTecnico, style: texto.bodySmall),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaciado.amplio,
            0,
            Espaciado.amplio,
            Espaciado.normal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sesion.objetivoFisiologico.isNotEmpty)
                Text(sesion.objetivoFisiologico, style: texto.bodyMedium),
              const SizedBox(height: Espaciado.corto),
              Text('${sesion.metros} metros', style: texto.bodySmall),
              for (final parte in sesion.partes)
                Padding(
                  padding: const EdgeInsets.only(top: Espaciado.corto),
                  child: Text(
                    '${parte.tipo.nombre}: ${parte.metros} m',
                    style: texto.bodySmall,
                  ),
                ),

              // Marcar, desde aquí (M24 a M28). **El mismo formulario que la
              // feature 003**: el nadador da la misma respuesta —cumplida,
              // esfuerzo, observaciones, molestia aparte— llegue por donde
              // llegue. Uno más pobre aquí haría que la respuesta dependiera
              // del camino.
              if (estado != null) ...[
                const SizedBox(height: Espaciado.normal),
                if (puedeMarcarse(sesion: sesion, hoy: hoy).si)
                  FormularioRegistro(
                    key: Key('marcar-${sesion.id ?? 'sin-id'}'),
                    sesion: sesion,
                    estado: estado!,
                    deEstePlan: mesociclo,
                  )
                else
                  // M24 y M28: no se puede, y se dice por qué. Sin control,
                  // porque un botón que no hace nada es peor que una frase.
                  Aviso(
                    tono: TonoDeAviso.informativo,
                    mensaje: puedeMarcarse(
                      sesion: sesion,
                      hoy: hoy,
                    ).comoSeLeExplica,
                    claveDelMensaje: Key('todavia-no-${sesion.id ?? 'sin-id'}'),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _diaDeLaSemana(DateTime fecha) => switch (fecha.weekday) {
    1 => 'Lunes',
    2 => 'Martes',
    3 => 'Miércoles',
    4 => 'Jueves',
    5 => 'Viernes',
    6 => 'Sábado',
    _ => 'Domingo',
  };
}
