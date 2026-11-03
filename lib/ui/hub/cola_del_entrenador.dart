/// La cola: lo que los nadadores le pidieron.
///
/// **El borrador se genera aquí, al abrir la petición.** No existe antes, y no
/// existe en el teléfono del nadador. Eso es lo que convierte «el nadador no
/// ve el borrador antes de la firma» en un hecho en lugar de una promesa que
/// hace la interfaz: si su dispositivo lo generara, el plan estaría guardado
/// ahí y «no puede verlo» sería cuestión de qué pantalla se le enseña.
///
/// Vive dentro del `Generar` del entrenador, junto al generador y el editor
/// que ya estaban. Los cinco destinos del HUB no cambian.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/auditoria/auditoria.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/entidades/plan.dart';

import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/peticiones/generar_desde_peticion.dart';
import 'package:natacion_app/dominio/peticiones/molestias_enlazadas.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/planes/tabla_auditoria.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

/// Lo que el entrenador decide sobre una petición.
typedef AlCerrarPeticion =
    Future<void> Function({
      required String nadadorId,
      required String decision,
      String? planId,
      String? motivo,
    });

class ColaDelEntrenador extends StatefulWidget {
  const ColaDelEntrenador({
    super.key,
    required this.peticiones,
    required this.nadadores,
    required this.molestias,
    required this.planes,
    required this.biblioteca,
    required this.versionMetodologia,
    this.alCerrar,
    this.hoyParaPruebas,
  });

  final RepositorioPeticiones? peticiones;
  final RepositorioNadadores nadadores;
  final LectorDeMolestias? molestias;

  /// Donde se guarda el borrador antes de firmarlo. **Sin esto no hay plan al
  /// que señalar**, y aprobar no puede hacer nada.
  final RepositorioPlanes? planes;

  final Biblioteca biblioteca;
  final String versionMetodologia;

  /// Cierra la petición **a través del servidor**: la fecha y el archivado son
  /// suyos. Nulo sin servidor.
  final AlCerrarPeticion? alCerrar;

  final DateTime? hoyParaPruebas;

  DateTime get hoy => hoyParaPruebas ?? DateTime.now();

  @override
  State<ColaDelEntrenador> createState() => _ColaDelEntrenadorState();
}

class _ColaDelEntrenadorState extends State<ColaDelEntrenador> {
  bool _cargando = true;
  List<PeticionDePlan> _peticiones = const [];
  Map<String, Nadador> _fichas = const {};
  String? _noSePudoLeer;

  /// Cuál está abierta. Nula = la lista.
  PeticionDePlan? _abierta;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final repo = widget.peticiones;
    if (repo == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }

    try {
      final peticiones = await repo.cola();
      final fichas = <String, Nadador>{};
      for (final peticion in peticiones) {
        final ficha = await widget.nadadores.obtener(peticion.nadadorId);
        if (ficha != null) fichas[peticion.nadadorId] = ficha;
      }

      if (!mounted) return;
      setState(() {
        _peticiones = peticiones;
        _fichas = fichas;
        _noSePudoLeer = null;
        _cargando = false;
      });
    } catch (problema) {
      // **Una cola que no se pudo leer no es una cola vacía.** Es el defecto
      // que este proyecto ya cometió dos veces, y las dos se vieron solo
      // corriendo la app.
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _noSePudoLeer =
            'No se pudo leer lo que te pidieron. Puede faltar lo último: '
            'esto es lo que había guardado ($problema).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        key: Key('cola-cargando'),
        child: CircularProgressIndicator(),
      );
    }

    final abierta = _abierta;
    if (abierta != null) {
      return _LaPeticionAbierta(
        peticion: abierta,
        ficha: _fichas[abierta.nadadorId],
        molestias: widget.molestias,
        planes: widget.planes,
        biblioteca: widget.biblioteca,
        versionMetodologia: widget.versionMetodologia,
        hoy: widget.hoy,
        alCerrar: widget.alCerrar,
        // **Al volver se recarga.** Sin esto, una petición ya respondida
        // seguía apareciendo en «esperando» y se respondía dos veces: el
        // servidor la cerraba bien y la pantalla no se enteraba. Lo encontró
        // el recorrido del quickstart, no una prueba.
        alVolver: () {
          setState(() {
            _abierta = null;
            _cargando = true;
          });
          unawaited(_cargar());
        },
      );
    }

    if (_noSePudoLeer != null) {
      return ListView(
        padding: const EdgeInsets.all(Espaciado.amplio),
        children: [
          Aviso(
            tono: TonoDeAviso.cuidado,
            icono: Icons.cloud_off_outlined,
            claveDelMensaje: const Key('cola-no-se-pudo-leer'),
            mensaje: _noSePudoLeer!,
          ),
        ],
      );
    }

    if (_peticiones.isEmpty) {
      return const Center(
        key: Key('cola-vacia'),
        child: Padding(
          padding: EdgeInsets.all(Espaciado.seccion),
          child: Text(
            'Nadie te ha pedido nada todavía.\n'
            'Cuando alguno te pida un entrenamiento, aparecerá aquí.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final esperando = _peticiones.where((p) => p.estaAbierta).toList();
    final respondidas = _peticiones.where((p) => !p.estaAbierta).toList();

    return ListView(
      padding: const EdgeInsets.all(Espaciado.amplio),
      children: [
        if (esperando.isNotEmpty) ...[
          Text(
            'Esperando tu respuesta',
            key: const Key('cola-esperando'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Espaciado.corto),
          for (final peticion in esperando) _Fila(peticion, _fichas, _abrir),
          const SizedBox(height: Espaciado.amplio),
        ],
        if (respondidas.isNotEmpty) ...[
          Text(
            'Ya respondidas',
            key: const Key('cola-respondidas'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Espaciado.corto),
          for (final peticion in respondidas) _Fila(peticion, _fichas, _abrir),
        ],
        const SizedBox(height: Espaciado.generoso),
      ],
    );
  }

  Future<void> _abrir(PeticionDePlan peticion) async {
    setState(() => _abierta = peticion);

    // Abrirla la pasa a «en revisión». **Lo mueve él**, por abrirla; nada la
    // mueve por tiempo transcurrido (FR-023).
    if (peticion.estado == EstadoDePeticion.esperando) {
      try {
        await widget.peticiones?.marcarEnRevision(peticion.nadadorId);
      } catch (_) {
        // Que no se pueda marcar no le impide trabajarla.
      }
    }
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.peticion, this.fichas, this.alAbrir);

  final PeticionDePlan peticion;
  final Map<String, Nadador> fichas;
  final ValueChanged<PeticionDePlan> alAbrir;

  @override
  Widget build(BuildContext context) {
    final nombre =
        fichas[peticion.nadadorId]?.nombre ?? peticion.nadadorId;
    final respuestas = peticion.respuestas;

    return Tarjeta(
      alPulsar: () => alAbrir(peticion),
      key: Key('abrir-peticion-${peticion.nadadorId}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Espaciado.minimo),
                Text(
                  '${respuestas.pruebaObjetivo} · '
                  '${respuestas.diasDisponibles.length} días · '
                  '${respuestas.duracionSesionMinutos} min · '
                  '${respuestas.longitudPiscina} m',
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _LaPeticionAbierta extends StatefulWidget {
  const _LaPeticionAbierta({
    required this.peticion,
    required this.ficha,
    required this.molestias,
    required this.planes,
    required this.biblioteca,
    required this.versionMetodologia,
    required this.hoy,
    required this.alCerrar,
    required this.alVolver,
  });

  final PeticionDePlan peticion;
  final Nadador? ficha;
  final LectorDeMolestias? molestias;
  final RepositorioPlanes? planes;
  final Biblioteca biblioteca;
  final String versionMetodologia;
  final DateTime hoy;
  final AlCerrarPeticion? alCerrar;
  final VoidCallback alVolver;

  @override
  State<_LaPeticionAbierta> createState() => _LaPeticionAbiertaState();
}

class _LaPeticionAbiertaState extends State<_LaPeticionAbierta> {
  final TextEditingController _motivo = TextEditingController();

  FaseAtr? _faseElegida;
  List<MolestiaEnlazada>? _molestias;
  bool _faltaElMotivo = false;
  String? _noSePudoResponder;

  @override
  void initState() {
    super.initState();
    _leerMolestias();
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  /// **Se leen donde ya viven. No se copian a ninguna parte** (FR-038).
  Future<void> _leerMolestias() async {
    try {
      final leidas = await widget.molestias?.recientesDe(
        widget.peticion.nadadorId,
        desde: widget.hoy.subtract(ventanaDeMolestias),
      );
      if (mounted) setState(() => _molestias = leidas ?? const []);
    } catch (_) {
      if (mounted) setState(() => _molestias = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ficha = widget.ficha;
    final textos = Theme.of(context).textTheme;

    final borrador = ficha == null
        ? null
        : generarDesdePeticion(
            peticion: widget.peticion,
            ficha: ficha,
            biblioteca: widget.biblioteca,
            versionMetodologia: widget.versionMetodologia,
            hoy: widget.hoy,
            faseElegida: _faseElegida,
          );

    return ListView(
      padding: const EdgeInsets.all(Espaciado.amplio),
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('volver-a-la-cola'),
              onPressed: widget.alVolver,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                ficha?.nombre ?? widget.peticion.nadadorId,
                style: textos.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: Espaciado.amplio),

        _LoQuePidio(
          respuestas: widget.peticion.respuestas,
          enviadaEn: widget.peticion.enviadaEn,
        ),
        const SizedBox(height: Espaciado.amplio),

        _Molestias(molestias: _molestias),
        const SizedBox(height: Espaciado.amplio),

        if (borrador != null) ...[
          _LaFase(
            borrador: borrador,
            alElegir: (fase) => setState(() => _faseElegida = fase),
          ),
          const SizedBox(height: Espaciado.amplio),
          if (borrador.resultado != null)
            _ElBorrador(resultado: borrador.resultado!),
        ],

        const SizedBox(height: Espaciado.amplio),
        _LaRespuesta(
          motivo: _motivo,
          faltaElMotivo: _faltaElMotivo,
          noSePudoResponder: _noSePudoResponder,
          puedeAprobar: _puedeAprobar(borrador),
          alRechazar: _rechazar,
          alAprobar: () => _aprobar(borrador),
        ),
        const SizedBox(height: Espaciado.generoso),
      ],
    );
  }

  /// **La misma auditoría que sus propios planes**, no una más suave: aprobar
  /// un plan que no la pasa sería firmar algo que él mismo no firmaría.
  bool _puedeAprobar(BorradorDePeticion? borrador) {
    final resultado = borrador?.resultado;
    if (resultado is! MicrocicloGenerado) return false;
    return Auditoria().evaluar(resultado.plan).apruebaSinBloqueos;
  }

  Future<void> _rechazar() async {
    final motivo = _motivo.text.trim();

    if (motivo.isEmpty) {
      // **Imposible, no desaconsejado.** Un rechazo sin motivo deja al nadador
      // sin saber por qué, y el que espera puede tener nueve años.
      setState(() => _faltaElMotivo = true);
      return;
    }

    setState(() {
      _faltaElMotivo = false;
      _noSePudoResponder = null;
    });

    try {
      await widget.alCerrar?.call(
        nadadorId: widget.peticion.nadadorId,
        decision: 'rechazada',
        motivo: motivo,
      );
      widget.alVolver();
    } catch (problema) {
      _decirQueNoSePudo(problema);
    }
  }

  Future<void> _aprobar(BorradorDePeticion? borrador) async {
    final resultado = borrador?.resultado;
    if (resultado is! MicrocicloGenerado) return;

    try {
      // **Primero se guarda, después se firma.** El borrador se genera en
      // memoria al abrir la petición y no existía en ninguna parte: al
      // aprobar se mandaba un `planId` nulo, el servidor contestaba «una
      // petición aprobada tiene que señalar a un plan», y la pantalla se
      // quedaba igual. Lo encontró el recorrido del quickstart.
      //
      // Nace en `borrador`, como cualquier salida de la automatización: lo
      // que la firma mueve a `aprobado` es el ciclo de vida que ya existe
      // desde la feature 001, no esta pantalla.
      final planId =
          resultado.plan.id ??
          await widget.planes?.guardarBorrador(resultado.plan);

      // **Y se firma de verdad.** Aprobar la petición *es* la firma: dejar el
      // plan en `borrador` obligaría al entrenador a buscarlo en el editor y
      // aprobarlo otra vez, con la petición diciendo «Aprobada» mientras
      // nadie ha firmado nada.
      //
      // Entregarlo sigue siendo el acto aparte que vive en `Ver Plan`: firmar
      // no es entregar.
      if (planId != null) {
        final firmado = resultado.plan.copiarCon(
          id: planId,
          estado: EstadoPlan.aprobado,
          fechaAprobacion: widget.hoy,
        );
        // La instantánea de auditoría, en el formato que la feature 001
        // guarda: qué criterios cumplía el plan el día que se firmó.
        final revisado = Auditoria().evaluar(firmado);
        await widget.planes?.guardarAprobado(firmado, {
          'cumpleTodo': revisado.apruebaSinBloqueos,
          'criterios': {
            for (final criterio in revisado.criterios)
              criterio.id: criterio.cumple,
          },
        });
      }

      await widget.alCerrar?.call(
        nadadorId: widget.peticion.nadadorId,
        decision: 'aprobada',
        planId: planId,
      );
      widget.alVolver();
    } catch (problema) {
      _decirQueNoSePudo(problema);
    }
  }

  /// Un botón que no hace nada y no explica por qué es el mismo defecto que
  /// una pantalla que gira para siempre, con otra cara.
  void _decirQueNoSePudo(Object problema) {
    if (!mounted) return;
    setState(() {
      _noSePudoResponder =
          'No se pudo mandar tu respuesta. Inténtalo otra vez cuando vuelva '
          'la conexión: lo que escribiste no se perdió ($problema).';
    });
  }
}

class _LoQuePidio extends StatelessWidget {
  const _LoQuePidio({required this.respuestas, required this.enviadaEn});

  final RespuestasDePeticion respuestas;
  final DateTime enviadaEn;

  @override
  Widget build(BuildContext context) => Tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lo que pidió', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Espaciado.corto),
        // **Cuándo la mandó** (FR-019). Estaba en el requisito, el disparador
        // lo estampa y la pantalla no lo enseñaba: una petición de hace tres
        // días y una de hace diez minutos se trabajan distinto.
        Text(
          'La mandó el ${enviadaEn.day}/${enviadaEn.month}',
          key: const Key('cuando-la-mando'),
        ),
        Text(
          '${respuestas.pruebaObjetivo} · ${respuestas.estiloObjetivo.nombre}',
        ),
        Text(
          '${respuestas.diasDisponibles.length} días a la semana, '
          '${respuestas.duracionSesionMinutos} minutos, piscina de '
          '${respuestas.longitudPiscina}',
        ),
        Text(
          respuestas.fechaDeCompetencia == null
              ? 'No sabía cuándo compite'
              : 'Compite el '
                    '${respuestas.fechaDeCompetencia!.day}/'
                    '${respuestas.fechaDeCompetencia!.month}',
        ),
      ],
    ),
  );
}

class _Molestias extends StatelessWidget {
  const _Molestias({required this.molestias});

  final List<MolestiaEnlazada>? molestias;

  @override
  Widget build(BuildContext context) {
    final leidas = molestias;
    if (leidas == null) return const SizedBox.shrink();

    if (leidas.isEmpty) {
      // **Se dice que no hay.** Un hueco en blanco se lee como «no le duele
      // nada», y esa es una afirmación que esta app no puede hacer.
      return const Aviso(
        tono: TonoDeAviso.informativo,
        icono: Icons.healing_outlined,
        claveDelMensaje: Key('sin-molestias-recientes'),
        mensaje:
            'No contó ninguna molestia en sus últimas cuatro semanas. Eso no '
            'quiere decir que no tenga ninguna: quiere decir que no la contó.',
      );
    }

    return Tarjeta(
      key: const Key('molestias-enlazadas'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lo que contó en sus sesiones',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Espaciado.corto),
          for (final molestia in leidas)
            Padding(
              padding: const EdgeInsets.only(top: Espaciado.minimo),
              child: Text(
                '${molestia.fecha.day}/${molestia.fecha.month} — '
                '${molestia.comoSeLee}',
              ),
            ),
          const SizedBox(height: Espaciado.corto),
          Text(
            'Esto no cambió el plan: decidir qué ejercicio está '
            'contraindicado es criterio clínico, y la app no lo tiene.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LaFase extends StatelessWidget {
  const _LaFase({required this.borrador, required this.alElegir});

  final BorradorDePeticion borrador;
  final ValueChanged<FaseAtr> alElegir;

  @override
  Widget build(BuildContext context) => Tarjeta(
    key: const Key('fase-derivada'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('La fase', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Espaciado.corto),
        Text(borrador.fase.porQue),
        if (borrador.faltaLaFase) ...[
          const SizedBox(height: Espaciado.corto),
          const Aviso(
            tono: TonoDeAviso.cuidado,
            icono: Icons.help_outline,
            claveDelMensaje: Key('falta-la-fase'),
            mensaje:
                'Sin fecha de competencia no se deriva la fase, y sin fase no '
                'se genera nada. Ponla tú y el borrador aparece.',
          ),
        ],
        const SizedBox(height: Espaciado.corto),
        Wrap(
          spacing: Espaciado.corto,
          children: [
            for (final fase in FaseAtr.values)
              ChoiceChip(
                key: Key('fase-${fase.name}'),
                label: Text(fase.nombre),
                selected: borrador.fase.fase == fase,
                onSelected: (_) => alElegir(fase),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ElBorrador extends StatelessWidget {
  const _ElBorrador({required this.resultado});

  final ResultadoGeneracion resultado;

  @override
  Widget build(BuildContext context) {
    if (resultado is GeneracionImposible) {
      // Lo pedido no cabe en su categoría. Se dice con la cuenta hecha, y
      // decide él: la app no corrige la petición por su cuenta.
      return Aviso(
        tono: TonoDeAviso.cuidado,
        icono: Icons.rule,
        claveDelMensaje: const Key('no-se-puede-generar'),
        mensaje: (resultado as GeneracionImposible).resumen,
      );
    }

    final plan = (resultado as MicrocicloGenerado).plan;

    return Column(
      key: const Key('borrador-de-la-peticion'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.nombre, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Espaciado.minimo),
              Text('${plan.sesiones.length} sesiones · ${plan.estado.nombre}'),
            ],
          ),
        ),
        const SizedBox(height: Espaciado.amplio),
        // **La misma tabla que sus propios planes.** Si aquí se enseñara una
        // versión reducida, aprobar desde la cola sería aprobar con menos
        // información que aprobar desde el editor.
        Padding(
          key: const Key('auditoria-del-borrador'),
          padding: EdgeInsets.zero,
          child: TablaAuditoria(resultado: Auditoria().evaluar(plan)),
        ),
      ],
    );
  }
}

class _LaRespuesta extends StatelessWidget {
  const _LaRespuesta({
    required this.motivo,
    required this.faltaElMotivo,
    required this.noSePudoResponder,
    required this.puedeAprobar,
    required this.alRechazar,
    required this.alAprobar,
  });

  final TextEditingController motivo;
  final bool faltaElMotivo;
  final String? noSePudoResponder;
  final bool puedeAprobar;
  final VoidCallback alRechazar;
  final VoidCallback alAprobar;

  @override
  Widget build(BuildContext context) => Tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tu respuesta', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Espaciado.corto),
        TextField(
          key: const Key('motivo-del-rechazo'),
          controller: motivo,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Si lo rechazas, dile por qué',
            helperText: 'Lo va a leer tal como lo escribas.',
          ),
        ),
        if (faltaElMotivo) ...[
          const SizedBox(height: Espaciado.corto),
          const Aviso(
            tono: TonoDeAviso.cuidado,
            icono: Icons.edit_outlined,
            claveDelMensaje: Key('falta-el-motivo'),
            mensaje:
                'Un rechazo sin motivo deja a quien lo pidió sin saber por '
                'qué. Escríbele algo, aunque sea corto.',
          ),
        ],
        if (noSePudoResponder != null) ...[
          const SizedBox(height: Espaciado.corto),
          Aviso(
            tono: TonoDeAviso.cuidado,
            icono: Icons.cloud_off_outlined,
            claveDelMensaje: const Key('no-se-pudo-responder'),
            mensaje: noSePudoResponder!,
          ),
        ],
        const SizedBox(height: Espaciado.amplio),
        Wrap(
          spacing: Espaciado.corto,
          runSpacing: Espaciado.corto,
          children: [
            FilledButton.icon(
              key: const Key('aprobar-peticion'),
              onPressed: puedeAprobar ? alAprobar : null,
              icon: const Icon(Icons.check),
              label: const Text('Aprobar'),
            ),
            OutlinedButton.icon(
              key: const Key('rechazar-peticion'),
              onPressed: alRechazar,
              icon: const Icon(Icons.close),
              label: const Text('Rechazar'),
            ),
          ],
        ),
      ],
    ),
  );
}
