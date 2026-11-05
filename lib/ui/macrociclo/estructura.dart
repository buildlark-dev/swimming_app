/// La pantalla de la confirmación única (M1 a M7, FR-001 a FR-009).
///
/// **Esta es la pantalla que sostiene la enmienda de la constitución v2.0.0.**
/// Lo que el entrenador hace aquí, una vez, es lo único que la metodología no
/// deja derivar: modelar la prueba y modelar al nadador, pasos 2 y 3 de la
/// sección 4. Todo lo de abajo —mesociclos, microciclos, sesiones— se deriva
/// por construcción cuando pulsa confirmar.
///
/// Tres cosas que esta pantalla no puede hacer, y por qué:
///
/// 1. **No guarda nada antes de que él confirme** (M10). El esqueleto vive en
///    este `State` y en ningún otro sitio. Derivar son catorce llamadas al
///    motor y da la tentación de cachear el resultado; se vuelven a hacer,
///    porque son puras y rápidas, y porque el cerrojo de
///    `nada_se_guarda_antes_test.dart` mira el almacenamiento.
/// 2. **No rellena los dos modelos con nada que él no haya escrito.** Lo que
///    se ofrece sale de `sugerencias.dart`, que solo lee su ficha.
/// 3. **No bloquea por una duración fuera de lo publicado.** Avisa con la
///    fuente a la vista y genera igual (M5): la sección 12 dice que la
///    natación usa fases más largas que la literatura general.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/macrociclo/derivar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/esqueleto_propuesto.dart';
import 'package:natacion_app/dominio/macrociclo/guardar_macrociclo.dart';
import 'package:natacion_app/dominio/macrociclo/macrociclo.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/componentes/aviso.dart';
import 'package:natacion_app/ui/componentes/boton.dart';
import 'package:natacion_app/ui/componentes/cabecera_seccion.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/ui/componentes/tarjeta.dart';
import 'package:natacion_app/ui/macrociclo/sugerencias.dart';
import 'package:natacion_app/ui/tema/espaciado.dart';
import 'package:natacion_app/ui/tema/avisos.dart';

class PantallaEstructura extends StatefulWidget {
  const PantallaEstructura({
    super.key,
    required this.ficha,
    required this.biblioteca,
    required this.versionMetodologia,
    required this.hoy,
    required this.planes,

    required this.macrociclos,
    required this.alConfirmar,
    this.indiceTerminos,
    this.alVolver,
    this.competenciaInicial,
  });

  /// La fecha de la competencia, si ya se sabe al abrir.
  ///
  /// Sirve para dos cosas: que el entrenador que ya tiene la convocatoria no
  /// la vuelva a poner, y que el banco de pantallas de la feature 005 pueda
  /// medir **esta pantalla con contenido**. Sin ella el banco mediría el
  /// estado vacío, y la 005 aprendió que un banco solo mide los caminos que
  /// monta: con un plan sin fase ATR, media pantalla no se pintaba en ninguna
  /// prueba.
  final DateTime? competenciaInicial;

  final Nadador ficha;
  final Biblioteca biblioteca;
  final String versionMetodologia;
  final DateTime hoy;

  final RepositorioPlanes planes;

  final RepositorioMacrociclos macrociclos;
  final IndiceTerminos? indiceTerminos;

  /// Qué hacer con lo guardado: normalmente, abrir la revisión.
  final void Function(MacrocicloGuardado) alConfirmar;

  final VoidCallback? alVolver;

  @override
  State<PantallaEstructura> createState() => _PantallaEstructuraState();
}

class _PantallaEstructuraState extends State<PantallaEstructura> {
  late final TextEditingController _nombre;
  late final TextEditingController _modeloDeLaPrueba;
  late final TextEditingController _modeloDelNadador;

  DateTime? _competencia;

  /// El esqueleto tal como él lo va dejando: fases y semanas. De aquí salen
  /// las fechas, nunca al revés.
  List<BloqueEditado> _bloques = const [];

  List<int> _diasPorSemana = const [1, 3, 5];
  int _duracion = 90;
  int _piscina = 25;

  bool _trabajando = false;
  String? _problema;
  List<Impedimento> _impedimentos = const [];

  @override
  void initState() {
    super.initState();

    _competencia = widget.competenciaInicial;

    final sugerido = sugerenciasDesdeLaFicha(widget.ficha);

    _nombre = TextEditingController(
      text: widget.ficha.pruebaObjetivo.trim().isEmpty
          ? ''
          : 'Hacia ${widget.ficha.pruebaObjetivo.trim()}',
    );
    // **Lo que él ya escribió, de vuelta.** Nada más.
    _modeloDeLaPrueba = TextEditingController(text: sugerido.paraLaPrueba);
    _modeloDelNadador = TextEditingController(text: sugerido.paraElNadador);

    final categoria = widget.ficha.categoria;
    _diasPorSemana = categoria == null
        ? const [1, 3, 5]
        : _primerosDias(
            categoria.sesionesPorSemana > 7
                ? (categoria.sesionesPorSemana / 2).ceil()
                : categoria.sesionesPorSemana,
          );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _modeloDeLaPrueba.dispose();
    _modeloDelNadador.dispose();
    super.dispose();
  }

  /// Los primeros `cuantos` días laborables de la semana, repartidos.
  ///
  /// Es un punto de partida editable, no una decisión: la categoría dice
  /// cuántas sesiones pide la metodología, y **qué días tiene piscina este
  /// nadador lo sabe él**.
  static List<int> _primerosDias(int cuantos) => switch (cuantos) {
    1 => const [3],
    2 => const [2, 4],
    3 => const [1, 3, 5],
    4 => const [1, 2, 4, 5],
    5 => const [1, 2, 3, 4, 5],
    6 => const [1, 2, 3, 4, 5, 6],
    _ => const [1, 2, 3, 4, 5, 6, 7],
  };

  List<FaltaEnPerfil> get _faltas => faltasParaElMacrociclo(widget.ficha);

  Categoria get _categoria =>
      widget.ficha.categoria ?? Categoria.iniciacion;

  /// El esqueleto propuesto para la fecha elegida. Se recalcula, no se guarda.
  EsqueletoPropuesto get _propuesto => esqueletoParaMacrociclo(
    fechaDeCompetencia: _competencia,
    hoy: widget.hoy,
    categoria: _categoria,
  );

  /// Los bloques de verdad: los de él si los tocó, los propuestos si no.
  List<BloqueConfirmado> get _bloquesActuales => _bloques.isEmpty
      ? _propuesto.bloques
      : recomponerElEsqueleto(
          bloques: _bloques,
          fechaDeCompetencia: _competencia!,
        );

  void _tomarLaPropuesta() {
    _bloques = [
      for (final bloque in _propuesto.bloques)
        (fase: bloque.fase, semanas: bloque.semanas),
    ];
  }

  Future<void> _elegirLaFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _competencia ?? widget.hoy.add(const Duration(days: 98)),
      firstDate: widget.hoy.add(const Duration(days: 1)),
      lastDate: widget.hoy.add(const Duration(days: 730)),
      helpText: 'Día de la competencia',
    );

    if (elegida == null) return;
    setState(() {
      _competencia = elegida;
      // Al cambiar la fecha se vuelve a la propuesta: mantener las semanas
      // que él puso para otra fecha dejaría un esqueleto que ya no cuadra con
      // el ancla, y él no lo habría pedido.
      _bloques = const [];
    });
  }

  /// Los avisos sobre los bloques que hay ahora, sean suyos o propuestos.
  List<String> get _avisos {
    if (_bloques.isEmpty) return _propuesto.avisos;

    return [
      for (final bloque in _bloquesActuales)
        if (!bloque.cabeEnLaVentanaPublicada && bloque.fase != null)
          '${bloque.fase!.nombre} de ${bloque.semanas} semanas: Issurin '
              '(2010) publica ${bloque.fase!.semanasSegunIssurin.$1} a '
              '${bloque.fase!.semanasSegunIssurin.$2}. La sección 12 anota '
              'que la natación usa fases más largas que la literatura '
              'general. Se avisa y decide usted.',
    ];
  }

  bool get _sePuedeConfirmar =>
      _faltas.isEmpty &&
      _competencia != null &&
      _bloquesActuales.isNotEmpty &&
      _nombre.text.trim().isNotEmpty &&
      _modeloDeLaPrueba.text.trim().isNotEmpty &&
      _modeloDelNadador.text.trim().isNotEmpty &&
      _diasPorSemana.isNotEmpty &&
      !_trabajando;

  Future<void> _confirmar() async {
    setState(() {
      _trabajando = true;
      _problema = null;
      _impedimentos = const [];
    });

    try {
      // **Aquí, y solo aquí, empieza a existir algo.**
      final estructura = EstructuraConfirmada(
        modeloDeLaPrueba: _modeloDeLaPrueba.text,
        modeloDelNadador: _modeloDelNadador.text,
        bloques: _bloquesActuales,
        confirmadaEn: widget.hoy,
        diasPorSemana: _diasPorSemana,
        duracionSesionMinutos: _duracion,
        longitudPiscina: _piscina,
      );

      final derivado = derivarMacrociclo(
        estructura: estructura,
        ficha: widget.ficha,
        biblioteca: widget.biblioteca,
        versionMetodologia: widget.versionMetodologia,
        nombre: _nombre.text.trim(),
        fechaDeCompetencia: _competencia!,
        indice: widget.indiceTerminos,
      );

      switch (derivado) {
        case DerivacionImposible(
          impedimentos: final impedimentos,
          enQueBloque: final donde,
        ):
          setState(() {
            _impedimentos = impedimentos;
            _problema = 'No se pudo derivar en $donde.';
            _trabajando = false;
          });

        case MacrocicloDerivado():
          final guardado = await guardarElMacrociclo(
            derivado: derivado,
            planes: widget.planes,

            macrociclos: widget.macrociclos,
          );
          if (!mounted) return;
          setState(() => _trabajando = false);
          widget.alConfirmar(guardado);
      }
    } on Object catch (problema) {
      if (!mounted) return;
      setState(() {
        _problema = problema.toString();
        _trabajando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final faltas = _faltas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estructura del macrociclo'),
        leading: widget.alVolver == null
            ? null
            : BackButton(onPressed: widget.alVolver),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(Espaciado.amplio),
          children: [
            if (faltas.isNotEmpty) ...[
              // M7, regla R3: se dice qué falta en lugar de proponer un
              // esqueleto construido sobre huecos.
              Aviso(
                tono: TonoDeAviso.error,
                titulo: 'Falta completar la ficha de '
                    '${widget.ficha.nombre.isEmpty ? 'este nadador' : widget.ficha.nombre}',
                mensaje:
                    'El macrociclo se construye con lo que usted ya observó. '
                    'Sin esto no se propone nada.',
                detalles: [
                  for (final falta in faltas)
                    LineaDeAviso(
                      icono: Icons.error_outline,
                      texto: falta.descripcion,
                    ),
                ],
              ),
              const SizedBox(height: Espaciado.seccion),
            ],

            if (faltas.isEmpty) ...[
              _LaFecha(
                competencia: _competencia,
                hoy: widget.hoy,
                alElegir: _elegirLaFecha,
                alElegirSemanas: (semanas) => setState(() {
                  _competencia = widget.hoy.add(
                    Duration(days: semanas * 7 - 1),
                  );
                  _bloques = const [];
                }),
                porQue: _propuesto.porQue,
              ),
              const SizedBox(height: Espaciado.seccion),

              if (_competencia != null) ...[
                const CabeceraSeccion(
                  titulo: 'El esqueleto que propone la app',
                  icono: Icons.view_timeline_outlined,
                ),
                const SizedBox(height: Espaciado.corto),
                Text(
                  'Son semanas contadas hacia atrás desde la competencia, con '
                  'las duraciones que cita la sección 12. Cámbielas: cada '
                  'bloque dice por qué salió así.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Espaciado.normal),

                for (var i = 0; i < _bloquesActuales.length; i++)
                  _BloqueEditable(
                    key: ValueKey('bloque-$i'),
                    indice: i,
                    bloque: _bloquesActuales[i],
                    usaAtr: _categoria.usaAtr,
                    alCambiarLaFase: (fase) => setState(() {
                      if (_bloques.isEmpty) _tomarLaPropuesta();
                      _bloques = [..._bloques]
                        ..[i] = (fase: fase, semanas: _bloques[i].semanas);
                    }),
                    alCambiarLasSemanas: (semanas) => setState(() {
                      if (_bloques.isEmpty) _tomarLaPropuesta();
                      _bloques = [..._bloques]
                        ..[i] = (fase: _bloques[i].fase, semanas: semanas);
                    }),
                    alQuitar: _bloquesActuales.length <= 1
                        ? null
                        : () => setState(() {
                            if (_bloques.isEmpty) _tomarLaPropuesta();
                            _bloques = [..._bloques]..removeAt(i);
                          }),
                  ),

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('anadir-bloque'),
                    onPressed: () => setState(() {
                      if (_bloques.isEmpty) _tomarLaPropuesta();
                      _bloques = [
                        (
                          fase: _categoria.usaAtr ? FaseAtr.acumulacion : null,
                          semanas: 4,
                        ),
                        ..._bloques,
                      ];
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir un bloque al principio'),
                  ),
                ),

                if (_avisos.isNotEmpty) ...[
                  const SizedBox(height: Espaciado.normal),
                  Aviso(
                    tono: TonoDeAviso.cuidado,
                    titulo: 'Fuera de las duraciones publicadas',
                    mensaje:
                        'No impide generar. La metodología dice avisar, no '
                        'suspender.',
                    detalles: [
                      for (final aviso in _avisos)
                        LineaDeAviso(
                          icono: Icons.info_outline,
                          texto: aviso,
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: Espaciado.seccion),
                _LosModelos(
                  prueba: _modeloDeLaPrueba,
                  nadador: _modeloDelNadador,
                  alEscribir: () => setState(() {}),
                ),

                const SizedBox(height: Espaciado.seccion),
                _ComoEntrena(
                  dias: _diasPorSemana,
                  duracion: _duracion,
                  piscina: _piscina,
                  sesionesQuePideLaCategoria: _categoria.sesionesPorSemana,
                  alCambiarLosDias: (dias) =>
                      setState(() => _diasPorSemana = dias),
                  alCambiarLaDuracion: (minutos) =>
                      setState(() => _duracion = minutos),
                  alCambiarLaPiscina: (metros) =>
                      setState(() => _piscina = metros),
                ),

                const SizedBox(height: Espaciado.seccion),
                Campo(
                  etiqueta: 'Nombre del macrociclo',
                  controlador: _nombre,
                  pista: 'Hacia el Departamental',
                  alCambiar: (_) => setState(() {}),
                ),

                if (_problema != null) ...[
                  const SizedBox(height: Espaciado.seccion),
                  Aviso(
                    tono: TonoDeAviso.error,
                    mensaje: _problema!,
                    claveDelMensaje: const Key('problema-al-confirmar'),
                    detalles: [
                      for (final impedimento in _impedimentos)
                        LineaDeAviso(
                          icono: Icons.block_outlined,
                          texto: impedimento.explicacion,
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: Espaciado.seccion),
                Text(
                  'Al confirmar se derivan los mesociclos, los microciclos y '
                  'todas las sesiones de una vez. No se le pedirá nada más '
                  'entre niveles. Hasta entonces no se ha guardado nada.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Espaciado.normal),
                BotonPrincipal(
                  clave: const Key('confirmar-la-estructura'),
                  etiqueta: 'Confirmar la estructura y generar',
                  icono: Icons.check_circle_outline,
                  trabajando: _trabajando,
                  alPulsar: _sePuedeConfirmar ? _confirmar : null,
                ),
                const SizedBox(height: Espaciado.generoso),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LaFecha extends StatelessWidget {
  const _LaFecha({
    required this.competencia,
    required this.hoy,
    required this.alElegir,
    required this.alElegirSemanas,
    required this.porQue,
  });

  final DateTime? competencia;
  final DateTime hoy;
  final VoidCallback alElegir;
  final ValueChanged<int> alElegirSemanas;
  final String porQue;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CabeceraSeccion(
            titulo: 'La competencia',
            icono: Icons.flag_outlined,
          ),
          const SizedBox(height: Espaciado.corto),
          Text(
            'Es el ancla: el macrociclo se cuenta hacia atrás desde ella.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Espaciado.normal),
          // Las semanas primero, que es como se piensa una temporada: «el
          // Departamental es en catorce semanas». La fecha exacta está al
          // lado para cuando ya se sabe el día.
          Wrap(
            spacing: Espaciado.corto,
            runSpacing: Espaciado.corto,
            children: [
              for (final semanas in const [8, 12, 14, 16, 20, 24])
                ChoiceChip(
                  key: Key('competencia-$semanas'),
                  label: Text('En $semanas semanas'),
                  selected:
                      competencia != null &&
                      competencia ==
                          hoy.add(Duration(days: semanas * 7 - 1)),
                  onSelected: (_) => alElegirSemanas(semanas),
                ),
            ],
          ),
          const SizedBox(height: Espaciado.normal),
          OutlinedButton.icon(
            key: const Key('elegir-la-fecha'),
            onPressed: alElegir,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              competencia == null
                  ? 'Elegir el día de la competencia'
                  : '${competencia!.day}/${competencia!.month}/${competencia!.year}',
            ),
          ),
          const SizedBox(height: Espaciado.corto),
          Text(
            porQue,
            key: const Key('por-que-el-esqueleto'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Un bloque, con su razón a la vista y todo cambiable (M2, M3).
class _BloqueEditable extends StatelessWidget {
  const _BloqueEditable({
    super.key,
    required this.indice,
    required this.bloque,
    required this.usaAtr,
    required this.alCambiarLaFase,
    required this.alCambiarLasSemanas,
    required this.alQuitar,
  });

  final int indice;
  final BloqueConfirmado bloque;
  final bool usaAtr;
  final ValueChanged<FaseAtr?> alCambiarLaFase;
  final ValueChanged<int> alCambiarLasSemanas;
  final VoidCallback? alQuitar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Espaciado.normal),
      child: Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bloque ${indice + 1}',
                    style: texto.titleMedium,
                  ),
                ),
                if (alQuitar != null)
                  IconButton(
                    key: Key('quitar-bloque-$indice'),
                    onPressed: alQuitar,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Quitar este bloque',
                  ),
              ],
            ),

            // **La razón, siempre legible** (M2). Un bloque cuya razón no se
            // puede leer es metodología decidida en silencio.
            Text(
              bloque.porQue,
              key: Key('por-que-bloque-$indice'),
              style: texto.bodyMedium,
            ),
            const SizedBox(height: Espaciado.corto),
            Text(
              'Del ${bloque.desde.day}/${bloque.desde.month} al '
              '${bloque.hasta.day}/${bloque.hasta.month}',
              style: texto.bodySmall,
            ),
            const SizedBox(height: Espaciado.normal),

            if (usaAtr)
              CampoDeOpciones<FaseAtr>(
                etiqueta: 'Fase',
                valor: bloque.fase,
                opciones: FaseAtr.values,
                nombreDe: (fase) => '${fase.nombre} · ${fase.objetivos}',
                alCambiar: alCambiarLaFase,
              )
            else
              Text(
                'Sin fase: esta categoría no trabaja por fases ATR.',
                key: Key('sin-fase-$indice'),
                style: texto.bodyMedium,
              ),

            CampoDeOpciones<int>(
              etiqueta: 'Semanas',
              valor: bloque.semanas,
              opciones: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16],
              nombreDe: (semanas) =>
                  '$semanas ${semanas == 1 ? 'semana' : 'semanas'}',
              alCambiar: (semanas) {
                if (semanas != null) alCambiarLasSemanas(semanas);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Los dos campos que son suyos y que ninguna fórmula deriva.
class _LosModelos extends StatelessWidget {
  const _LosModelos({
    required this.prueba,
    required this.nadador,
    required this.alEscribir,
  });

  final TextEditingController prueba;
  final TextEditingController nadador;
  final VoidCallback alEscribir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CabeceraSeccion(
          titulo: 'Lo que pone usted',
          icono: Icons.edit_note_outlined,
        ),
        const SizedBox(height: Espaciado.corto),
        Text(
          'Pasos 2 y 3 de la sección 4. La app no los deriva de nada: si hay '
          'algo escrito, es lo que usted ya anotó en la ficha.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Espaciado.normal),
        Campo(
          etiqueta: 'Modelo de la prueba',
          controlador: prueba,
          lineas: 4,
          ayuda: 'Las exigencias reales de la prueba objetivo.',
          pista: 'Qué pide esta prueba: ritmo, viraje, salida, final.',
          alCambiar: (_) => alEscribir(),
        ),
        const SizedBox(height: Espaciado.normal),
        Campo(
          etiqueta: 'Modelo del nadador',
          controlador: nadador,
          lineas: 5,
          ayuda:
              'Estilo dominante, errores, ritmo, tolerancia a la fatiga, '
              'recuperación, motivación.',
          pista: 'Cómo es este nadador, con lo que usted le ha visto.',
          alCambiar: (_) => alEscribir(),
        ),
      ],
    );
  }
}

/// Las tres entradas del motor que nadie puede suponer.
class _ComoEntrena extends StatelessWidget {
  const _ComoEntrena({
    required this.dias,
    required this.duracion,
    required this.piscina,
    required this.sesionesQuePideLaCategoria,
    required this.alCambiarLosDias,
    required this.alCambiarLaDuracion,
    required this.alCambiarLaPiscina,
  });

  final List<int> dias;
  final int duracion;
  final int piscina;
  final int sesionesQuePideLaCategoria;
  final ValueChanged<List<int>> alCambiarLosDias;
  final ValueChanged<int> alCambiarLaDuracion;
  final ValueChanged<int> alCambiarLaPiscina;

  static const _nombres = {
    1: 'Lun',
    2: 'Mar',
    3: 'Mié',
    4: 'Jue',
    5: 'Vie',
    6: 'Sáb',
    7: 'Dom',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CabeceraSeccion(
          titulo: 'Cómo entrena',
          icono: Icons.calendar_month_outlined,
        ),
        const SizedBox(height: Espaciado.corto),
        Text(
          'Su categoría pide $sesionesQuePideLaCategoria sesiones por semana. '
          'Qué días tiene piscina lo sabe usted.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Espaciado.normal),
        Wrap(
          spacing: Espaciado.corto,
          runSpacing: Espaciado.corto,
          children: [
            for (final dia in const [1, 2, 3, 4, 5, 6, 7])
              FilterChip(
                key: Key('dia-$dia'),
                label: Text(_nombres[dia]!),
                selected: dias.contains(dia),
                onSelected: (elegido) {
                  final nuevos = [...dias];
                  if (elegido) {
                    nuevos.add(dia);
                  } else {
                    nuevos.remove(dia);
                  }
                  alCambiarLosDias(nuevos..sort());
                },
              ),
          ],
        ),
        const SizedBox(height: Espaciado.normal),
        CampoDeOpciones<int>(
          etiqueta: 'Duración de la sesión',
          valor: duracion,
          opciones: const [45, 60, 75, 90, 105, 120, 150],
          nombreDe: (minutos) => '$minutos minutos',
          alCambiar: (minutos) {
            if (minutos != null) alCambiarLaDuracion(minutos);
          },
        ),
        CampoDeOpciones<int>(
          etiqueta: 'Piscina',
          valor: piscina,
          opciones: const [25, 50],
          nombreDe: (metros) => '$metros metros',
          alCambiar: (metros) {
            if (metros != null) alCambiarLaPiscina(metros);
          },
        ),
      ],
    );
  }
}
