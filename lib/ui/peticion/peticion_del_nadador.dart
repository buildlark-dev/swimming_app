/// El `Generar` del nadador: pedirle un entrenamiento a su entrenador.
///
/// Hasta la feature 007 este destino decía «todavía no». Es la primera vez en
/// el producto que un nadador **propone** algo en lugar de solo recibir y
/// responder, y por eso toca de frente el principio IV: lo que sale de aquí es
/// una petición, no un plan.
///
/// La lista es de seis preguntas, y es corta por necesidad. De los once datos
/// obligatorios de la sección 5 del prompt maestro, el nadador solo puede
/// responder cinco y confirmar dos: la categoría la asigna el entrenador, la
/// fase ATR y el componente acentuado se derivan, el diagnóstico técnico es
/// observación suya, y las molestias salen de sus sesiones. Preguntarle el
/// resto sería pedirle que opine sobre lo que no le toca.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:natacion_app/datos/local/almacen_local.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/peticiones/peticion.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/peticion/estado_de_mi_peticion.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';

/// Duraciones que se ofrecen, en minutos. Tocar, no escribir (P3).
const List<int> duracionesOfrecidas = [45, 60, 75, 90, 120];

/// Distancias que se ofrecen para la prueba objetivo.
const List<int> distanciasOfrecidas = [50, 100, 200, 400, 800, 1500];

/// Donde vive lo respondido a medias, en el almacen de esta cuenta.
const String coleccionDeLoRespondido = 'peticionAMedias';

class PeticionDelNadador extends StatefulWidget {
  const PeticionDelNadador({
    super.key,
    required this.nadadorId,
    required this.nadadores,
    this.peticiones,
    this.estaRetenida,
    this.alReintentarLoRetenido,
    this.almacen,
    this.hoyParaPruebas,
  });

  /// Su ficha. Nulo cuando su cuenta todavía no está vinculada a ninguna.
  final String? nadadorId;

  final RepositorioNadadores nadadores;

  /// Nulo sin servidor: en modo local no hay a quien pedirle nada ni donde
  /// guardarlo, y la pantalla lo dice en lugar de ofrecer una lista que no
  /// lleva a ninguna parte.
  final RepositorioPeticiones? peticiones;

  /// Si lo que mandó sigue retenido en el dispositivo por falta del
  /// consentimiento del acudiente. Nulo cuando no hay nada que consultar.
  final Future<bool> Function(String nadadorId)? estaRetenida;

  /// Manda lo que quedó retenido, por si el acudiente ya autorizó. Se llama
  /// al abrir la pantalla, que es el momento en que algo pudo cambiar.
  final Future<void> Function(String nadadorId)? alReintentarLoRetenido;

  /// Donde se guarda lo respondido a medias, para que sobreviva a cerrar la
  /// app (P5). Nulo en pruebas que no lo necesitan.
  final AlmacenLocal? almacen;

  /// Se inyecta para poder probar sin que la fecha de hoy mueva los días.
  final DateTime? hoyParaPruebas;

  DateTime get hoy => hoyParaPruebas ?? DateTime.now();

  @override
  State<PeticionDelNadador> createState() => _PeticionDelNadadorState();
}

class _PeticionDelNadadorState extends State<PeticionDelNadador> {
  bool _cargando = true;
  Nadador? _ficha;
  PeticionDePlan? _peticion;
  bool _retenida = false;
  String? _noSePudoCargar;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Carga cada cosa por separado, y si una falla sigue con las demás.
  ///
  /// La lección ya costó dos pantallas en la feature 007: un fallo al leer una
  /// cosa no puede dejar la pantalla entera sin aparecer, y la rueda dando
  /// vueltas no se distingue de estar tardando.
  Future<void> _cargar() async {
    final id = widget.nadadorId;
    if (id == null || id.trim().isEmpty || widget.peticiones == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }

    // **Primero se reintenta lo retenido.** Estaba escrito y nadie lo
    // llamaba: el acudiente autorizaba y la solicitud se quedaba en el
    // teléfono para siempre. Un requisito implementado y desconectado es un
    // requisito incumplido.
    try {
      await widget.alReintentarLoRetenido?.call(id);
    } catch (_) {
      // Si no se puede, sigue retenida. No se pierde.
    }

    Nadador? ficha;
    PeticionDePlan? peticion;
    String? fallo;

    try {
      ficha = await widget.nadadores.obtener(id);
    } catch (problema) {
      fallo = 'No se pudo leer tu ficha ($problema).';
    }

    try {
      peticion = await widget.peticiones!.miPeticion(id);
    } catch (problema) {
      fallo = fallo == null
          ? 'No se pudo leer tu solicitud ($problema).'
          : '$fallo Y tu solicitud tampoco.';
    }

    var retenida = false;
    try {
      retenida = await widget.estaRetenida?.call(id) ?? false;
    } catch (_) {
      // No saberlo no puede dejar la pantalla sin aparecer.
    }

    if (!mounted) return;
    setState(() {
      _ficha = ficha;
      _peticion = peticion;
      _retenida = retenida;
      _noSePudoCargar = fallo;
      _cargando = false;
    });
  }

  /// Vuelve a intentarlo porque el nadador lo pidió: su acudiente ya autorizó,
  /// y esperar a que una caché se refresque no es una respuesta.
  Future<void> _reintentar() async {
    setState(() => _cargando = true);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        key: Key('peticion-cargando'),
        child: CircularProgressIndicator(),
      );
    }

    final peticion = _peticion;
    if (peticion != null) {
      return EstadoDeMiPeticion(
        peticion: peticion,
        esperandoAutorizacion: _retenida,
        alReintentar: _retenida ? _reintentar : null,
        alPedirDeNuevo: peticion.estaAbierta
            ? null
            : () => setState(() => _peticion = null),
      );
    }

    final peticiones = widget.peticiones;
    if (peticiones == null) {
      return const _Explicacion(
        clave: Key('peticion-sin-servidor'),
        icono: Icons.cloud_off_outlined,
        titulo: 'Sin servidor no se puede pedir',
        texto:
            'En modo local no hay a quién mandarle la solicitud. Entra con tu '
            'cuenta para pedirle su entrenamiento a tu entrenador.',
      );
    }

    final ficha = _ficha;

    if (ficha == null) {
      return _Explicacion(
        clave: const Key('peticion-sin-ficha'),
        icono: Icons.pool_outlined,
        titulo: 'Todavía no estás inscrito',
        texto:
            'Cuando tu entrenador te inscriba, desde aquí vas a poder pedirle '
            'tu entrenamiento.',
        aviso: _noSePudoCargar,
      );
    }

    if (!_fichaCompleta(ficha)) {
      // El motor parte de la ficha: sin categoría no hay rangos de volumen ni
      // frecuencia, y generar con huecos rellenados a ojo es lo que la regla
      // R3 prohíbe. Se dice a quién le toca arreglarlo.
      return _Explicacion(
        clave: const Key('peticion-ficha-incompleta'),
        icono: Icons.edit_note_outlined,
        titulo: 'A tu ficha le falta algo',
        texto:
            'Tu entrenador tiene que completar tu categoría y tu prueba '
            'objetivo antes de que puedas pedirle un entrenamiento.',
        aviso: _noSePudoCargar,
      );
    }

    return _ListaDePreguntas(
      ficha: ficha,
      hoy: widget.hoy,
      peticiones: peticiones,
      almacen: widget.almacen,
      // **Al mandarla se vuelve a mirar si quedó retenida.** Sin esto, a un
      // menor sin consentimiento la pantalla le decía «Le llegó. Él la revisa
      // cuando pueda» sobre algo que seguía en su teléfono: el aviso correcto
      // solo salía al reabrir la pantalla. Lo encontró el recorrido del
      // quickstart, y es la mitad de P9 que se escapa — decirlo es una cosa,
      // no decir lo contrario es otra.
      alEnviarse: (enviada) async {
        var retenida = false;
        try {
          retenida =
              await widget.estaRetenida?.call(enviada.nadadorId) ?? false;
        } catch (_) {
          // No saberlo no puede dejar la pantalla a medias.
        }

        if (!mounted) return;
        setState(() {
          _peticion = enviada;
          _retenida = retenida;
        });
      },
    );
  }

  bool _fichaCompleta(Nadador ficha) =>
      ficha.categoria != null && ficha.pruebaObjetivo.trim().isNotEmpty;
}

/// Una pregunta de la lista. Existe como tipo para poder contarlas: que sean
/// **seis y no siete** es parte del contrato (P1).
class Pregunta extends StatelessWidget {
  const Pregunta({super.key, required this.titulo, required this.respuesta});

  final String titulo;
  final Widget respuesta;

  @override
  Widget build(BuildContext context) => Tarjeta(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Espaciado.corto),
        respuesta,
      ],
    ),
  );
}

class _ListaDePreguntas extends StatefulWidget {
  const _ListaDePreguntas({
    required this.ficha,
    required this.hoy,
    required this.peticiones,
    required this.almacen,
    required this.alEnviarse,
  });

  final Nadador ficha;
  final DateTime hoy;
  final RepositorioPeticiones peticiones;
  final AlmacenLocal? almacen;
  final ValueChanged<PeticionDePlan> alEnviarse;

  @override
  State<_ListaDePreguntas> createState() => _ListaDePreguntasState();
}

class _ListaDePreguntasState extends State<_ListaDePreguntas> {
  @override
  void initState() {
    super.initState();
    _recordarLoRespondido();
  }

  /// Vuelve a poner lo que estaba a medias. **Si falla, no pasa nada**: se
  /// empieza con la propuesta, que es peor que recordarlo pero mejor que una
  /// pantalla que no aparece.
  Future<void> _recordarLoRespondido() async {
    final almacen = widget.almacen;
    if (almacen == null) return;

    try {
      final guardado = await almacen.leer(
        coleccionDeLoRespondido,
        widget.ficha.id ?? '',
      );
      if (guardado == null || !mounted) return;

      setState(() {
        _estilo =
            Estilo.porNombre(guardado['estilo'] as String? ?? '') ?? _estilo;
        _prueba = guardado['prueba'] as String? ?? _prueba;
        _duracion = (guardado['duracion'] as num?)?.toInt() ?? _duracion;
        _piscina = (guardado['piscina'] as num?)?.toInt() ?? _piscina;
        _noSabeCuando = guardado['noSabeCuando'] == true;
        final cuando = guardado['competencia'];
        _competencia = cuando is String ? DateTime.tryParse(cuando) : null;
        final dias = guardado['dias'];
        if (dias is List && dias.isNotEmpty) {
          _dias
            ..clear()
            ..addAll(dias.whereType<num>().map((d) => d.toInt()));
        }
      });
    } catch (_) {
      // Un almacén que no se puede leer no deja a nadie sin pedir.
    }
  }

  Future<void> _guardarLoRespondido() async {
    try {
      await widget.almacen
          ?.escribir(coleccionDeLoRespondido, widget.ficha.id ?? '', {
            'estilo': _estilo.nombre,
            'prueba': _prueba,
            'competencia': _competencia?.toIso8601String(),
            'noSabeCuando': _noSabeCuando,
            'dias': _dias.toList()..sort(),
            'duracion': _duracion,
            'piscina': _piscina,
          });
    } catch (_) {
      // Guardar es una comodidad, no la petición. Si falla, se sigue.
    }
  }

  /// Cada toque se guarda. Es barato y evita tener que decidir cuándo.
  void _anotar(VoidCallback cambio) {
    setState(cambio);
    unawaited(_guardarLoRespondido());
  }

  late Estilo _estilo = widget.ficha.estiloObjetivo ?? Estilo.libre;
  late String _prueba = widget.ficha.pruebaObjetivo;

  DateTime? _competencia;
  bool _noSabeCuando = false;

  /// Días de la semana elegidos, 1 = lunes. Empieza con una propuesta
  /// razonable para que la lista no arranque en blanco.
  final Set<int> _dias = {1, 3};

  int _duracion = 60;
  int _piscina = 25;

  bool _enviando = false;
  String? _falta;
  String? _noSePudoEnviar;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('lista-de-preguntas'),
    padding: const EdgeInsets.all(Espaciado.amplio),
    children: [
      Text(
        'Pídele tu entrenamiento',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: Espaciado.corto),
      Text(
        'Responde estas seis cosas y tu entrenador lo prepara. Él decide qué '
        'entrenas: esto es lo que él necesita saber de ti.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: Espaciado.amplio),

      Pregunta(
        key: const Key('pregunta-estilo'),
        titulo: '¿Qué quieres trabajar?',
        respuesta: Wrap(
          spacing: Espaciado.corto,
          children: [
            for (final estilo in Estilo.values)
              ChoiceChip(
                key: Key('estilo-${estilo.name}'),
                label: Text(estilo.nombre),
                selected: _estilo == estilo,
                onSelected: (_) => _anotar(() => _estilo = estilo),
              ),
          ],
        ),
      ),
      const SizedBox(height: Espaciado.amplio),

      Pregunta(
        key: const Key('pregunta-prueba'),
        titulo: '¿Qué prueba te viene?',
        respuesta: Wrap(
          spacing: Espaciado.corto,
          children: [
            for (final prueba in _pruebasOfrecidas())
              ChoiceChip(
                key: Key('prueba-$prueba'),
                label: Text(prueba),
                selected: _prueba == prueba,
                onSelected: (_) => _anotar(() => _prueba = prueba),
              ),
          ],
        ),
      ),
      const SizedBox(height: Espaciado.amplio),

      Pregunta(
        key: const Key('pregunta-competencia'),
        titulo: '¿Cuándo es tu competencia?',
        respuesta: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Espaciado.corto,
              children: [
                for (final semanas in [2, 4, 8, 12])
                  ChoiceChip(
                    key: Key('competencia-$semanas'),
                    label: Text('En $semanas semanas'),
                    selected:
                        !_noSabeCuando && _competencia == _enSemanas(semanas),
                    onSelected: (_) => _anotar(() {
                      _noSabeCuando = false;
                      _competencia = _enSemanas(semanas);
                    }),
                  ),
                ChoiceChip(
                  key: const Key('no-se-cuando-compito'),
                  label: const Text('No lo sé'),
                  selected: _noSabeCuando,
                  onSelected: (_) => _anotar(() {
                    _noSabeCuando = true;
                    _competencia = null;
                  }),
                ),
              ],
            ),
            if (_noSabeCuando) ...[
              const SizedBox(height: Espaciado.corto),
              Text(
                'No pasa nada: tu entrenador lo decide él.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: Espaciado.amplio),

      Pregunta(
        key: const Key('pregunta-dias'),
        titulo: '¿Qué días puedes entrenar?',
        respuesta: Wrap(
          spacing: Espaciado.corto,
          children: [
            for (var dia = 1; dia <= 7; dia++)
              FilterChip(
                key: Key('dia-$dia'),
                label: Text(_nombreDelDia(dia)),
                selected: _dias.contains(dia),
                onSelected: (elegido) => _anotar(() {
                  if (elegido) {
                    _dias.add(dia);
                  } else {
                    _dias.remove(dia);
                  }
                }),
              ),
          ],
        ),
      ),
      const SizedBox(height: Espaciado.amplio),

      Pregunta(
        key: const Key('pregunta-duracion'),
        titulo: '¿Cuánto dura cada entrenamiento?',
        respuesta: Wrap(
          spacing: Espaciado.corto,
          children: [
            for (final minutos in duracionesOfrecidas)
              ChoiceChip(
                key: Key('duracion-$minutos'),
                label: Text('$minutos min'),
                selected: _duracion == minutos,
                onSelected: (_) => _anotar(() => _duracion = minutos),
              ),
          ],
        ),
      ),
      const SizedBox(height: Espaciado.amplio),

      Pregunta(
        key: const Key('pregunta-piscina'),
        titulo: '¿En qué piscina entrenas?',
        respuesta: Wrap(
          spacing: Espaciado.corto,
          children: [
            for (final metros in [25, 50])
              ChoiceChip(
                key: Key('piscina-$metros'),
                label: Text('$metros metros'),
                selected: _piscina == metros,
                onSelected: (_) => _anotar(() => _piscina = metros),
              ),
          ],
        ),
      ),
      const SizedBox(height: Espaciado.amplio),

      if (_falta != null) ...[
        // De cuidado y no de error: no se perdió nada, falta algo por tocar.
        // El rojo está reservado a dos pantallas desde la feature 005.
        Aviso(
          tono: TonoDeAviso.cuidado,
          icono: Icons.help_outline,
          claveDelMensaje: const Key('falta-algo'),
          mensaje: _falta!,
        ),
        const SizedBox(height: Espaciado.amplio),
      ],

      if (_noSePudoEnviar != null) ...[
        Aviso(
          tono: TonoDeAviso.cuidado,
          icono: Icons.cloud_off_outlined,
          claveDelMensaje: const Key('no-se-pudo-enviar'),
          mensaje: _noSePudoEnviar!,
        ),
        const SizedBox(height: Espaciado.amplio),
      ],

      FilledButton.icon(
        key: const Key('enviar-peticion'),
        onPressed: _enviando ? null : _enviar,
        icon: const Icon(Icons.send_outlined),
        label: const Text('Pedir mi entrenamiento'),
      ),
      const SizedBox(height: Espaciado.generoso),
    ],
  );

  List<String> _pruebasOfrecidas() {
    final ofrecidas = [
      for (final distancia in distanciasOfrecidas)
        '$distancia ${_estilo.nombre}',
    ];

    // La de su ficha va siempre, aunque no esté en la lista: es la que su
    // entrenador le puso.
    final suya = widget.ficha.pruebaObjetivo.trim();
    if (suya.isNotEmpty && !ofrecidas.contains(suya)) ofrecidas.insert(0, suya);

    return ofrecidas;
  }

  DateTime _enSemanas(int semanas) =>
      _soloLaFecha(widget.hoy.add(Duration(days: semanas * 7)));

  Future<void> _enviar() async {
    if (_dias.isEmpty) {
      setState(() {
        _falta = 'Falta decir qué días puedes entrenar. Toca al menos uno.';
        _noSePudoEnviar = null;
      });
      return;
    }

    if (_prueba.trim().isEmpty) {
      setState(() {
        _falta = 'Falta decir qué prueba te viene.';
        _noSePudoEnviar = null;
      });
      return;
    }

    setState(() {
      _falta = null;
      _noSePudoEnviar = null;
      _enviando = true;
    });

    try {
      final respuestas = RespuestasDePeticion(
        estiloObjetivo: _estilo,
        pruebaObjetivo: _prueba,
        fechaDeCompetencia: _noSabeCuando ? null : _competencia,
        diasDisponibles: _proximosDias(),
        duracionSesionMinutos: _duracion,
        longitudPiscina: _piscina,
      );

      await widget.peticiones.enviar(
        nadadorId: widget.ficha.id!,
        respuestas: respuestas,
      );

      // Mandada: lo guardado a medias ya no sirve, y dejarlo haria que la
      // siguiente peticion empezara con las respuestas de esta.
      try {
        await widget.almacen?.borrar(
          coleccionDeLoRespondido,
          widget.ficha.id ?? '',
        );
      } catch (_) {}

      if (!mounted) return;
      widget.alEnviarse(
        PeticionDePlan(
          nadadorId: widget.ficha.id!,
          enviadaEn: widget.hoy,
          respuestas: respuestas,
          estado: EstadoDePeticion.esperando,
        ),
      );
    } catch (problema) {
      // **Lo que no salió se dice.** Darlo por enviado sería lo que esta app
      // ya ha hecho mal dos veces de otra forma: dejar a alguien creyendo que
      // algo pasó.
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _noSePudoEnviar =
            'No se pudo mandar tu solicitud. Inténtalo cuando vuelva la '
            'conexión: lo que respondiste no se perdió.';
      });
    }
  }

  /// Las fechas reales de los días elegidos, dentro de la semana que viene.
  List<DateTime> _proximosDias() {
    final hoy = _soloLaFecha(widget.hoy);

    return [
      for (final dia in (_dias.toList()..sort()))
        hoy.add(Duration(days: (dia - hoy.weekday + 7) % 7 + 1)),
    ];
  }
}

String _nombreDelDia(int dia) => switch (dia) {
  1 => 'Lun',
  2 => 'Mar',
  3 => 'Mié',
  4 => 'Jue',
  5 => 'Vie',
  6 => 'Sáb',
  _ => 'Dom',
};

DateTime _soloLaFecha(DateTime momento) =>
    DateTime(momento.year, momento.month, momento.day);

class _Explicacion extends StatelessWidget {
  const _Explicacion({
    required this.clave,
    required this.icono,
    required this.titulo,
    required this.texto,
    this.aviso,
  });

  final Key clave;
  final IconData icono;
  final String titulo;
  final String texto;
  final String? aviso;

  @override
  Widget build(BuildContext context) => Center(
    key: clave,
    child: Padding(
      padding: const EdgeInsets.all(Espaciado.seccion),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 48),
          const SizedBox(height: Espaciado.amplio),
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Espaciado.corto),
          Text(texto, textAlign: TextAlign.center),
          if (aviso != null) ...[
            const SizedBox(height: Espaciado.amplio),
            Aviso(
              tono: TonoDeAviso.cuidado,
              icono: Icons.cloud_off_outlined,
              claveDelMensaje: const Key('peticion-no-se-pudo-leer'),
              mensaje: aviso!,
            ),
          ],
        ],
      ),
    ),
  );
}
