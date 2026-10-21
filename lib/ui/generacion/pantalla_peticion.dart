/// Formulario de generación: el protocolo de inicio de la sección 5.
///
/// El entrenador declara sus datos y obtiene el microciclo. Si algo falta o se
/// contradice, ve el panel de impedimentos en lugar de un plan a medias.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/dominio/biblioteca/biblioteca.dart';
import 'package:natacion_app/dominio/biblioteca/indice_terminos.dart';
import 'package:natacion_app/dominio/generacion/generador.dart';
import 'package:natacion_app/dominio/generacion/peticion.dart';
import 'package:natacion_app/dominio/generacion/resultado.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/dominio/metodologia/fases_atr.dart';
import 'package:natacion_app/ui/generacion/panel_impedimentos.dart';

class PantallaPeticion extends StatefulWidget {
  const PantallaPeticion({
    super.key,
    required this.biblioteca,
    required this.alGenerar,
    this.indiceTerminos,
  });

  final Biblioteca biblioteca;

  /// Vocabulario de diagnóstico del entrenador. Sin él, un diagnóstico se
  /// reporta como vacío de Biblioteca en lugar de resolverse a ojo.
  final IndiceTerminos? indiceTerminos;

  /// Qué hacer con el microciclo generado: normalmente, abrirlo en el editor.
  final void Function(MicrocicloGenerado) alGenerar;

  @override
  State<PantallaPeticion> createState() => _PantallaPeticionState();
}

class _PantallaPeticionState extends State<PantallaPeticion> {
  late final Generador _generador = Generador(
    biblioteca: widget.biblioteca,
    indice: widget.indiceTerminos,
  );

  Categoria _categoria = Categoria.precompetitivo;
  Estilo _estilo = Estilo.libre;
  FaseAtr? _fase = FaseAtr.acumulacion;
  int _piscina = 25;
  int _duracion = 90;
  int _dias = 3;

  final TextEditingController _prueba =
      TextEditingController(text: '100 Libre');
  final TextEditingController _componente =
      TextEditingController(text: 'Técnica de eficiencia');
  final TextEditingController _diagnostico = TextEditingController();
  final TextEditingController _lesiones = TextEditingController();

  List<Impedimento> _impedimentos = const [];
  MicrocicloGenerado? _ultimoGenerado;

  @override
  void dispose() {
    _prueba.dispose();
    _componente.dispose();
    _diagnostico.dispose();
    _lesiones.dispose();
    super.dispose();
  }

  List<String> _lineas(TextEditingController controlador) => controlador.text
      .split('\n')
      .map((linea) => linea.trim())
      .where((linea) => linea.isNotEmpty)
      .toList();

  PeticionGeneracion get _peticion => PeticionGeneracion(
        categoria: _categoria,
        estiloObjetivo: _estilo,
        pruebaObjetivo: _prueba.text,
        faseAtr: _categoria.usaAtr ? _fase : null,
        componenteAcentuado: _componente.text,
        diasDisponibles: List.generate(
          _dias,
          (i) => DateTime.now().add(Duration(days: i)),
        ),
        longitudPiscina: _piscina,
        duracionSesionMinutos: _duracion,
        diagnosticoTecnico: _lineas(_diagnostico),
        lesiones: _lineas(_lesiones),
      );

  void _generar() {
    final resultado = _generador.generar(_peticion);

    setState(() {
      switch (resultado) {
        case GeneracionImposible(:final impedimentos):
          _impedimentos = impedimentos;
          _ultimoGenerado = null;
        case MicrocicloGenerado():
          _impedimentos = const [];
          _ultimoGenerado = resultado;
      }
    });

    if (resultado is MicrocicloGenerado) widget.alGenerar(resultado);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generar microciclo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generar,
        icon: const Icon(Icons.auto_awesome_outlined),
        label: const Text('Generar la semana'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PanelImpedimentos(impedimentos: _impedimentos),
          if (_impedimentos.isNotEmpty) const SizedBox(height: 16),

          if (_ultimoGenerado != null) ...[
            PanelAvisosGeneracion(resultado: _ultimoGenerado!),
            const SizedBox(height: 16),
          ],

          _Bloque(
            titulo: 'El nadador o el grupo',
            children: [
              CampoDeOpciones<Categoria>(
                etiqueta: 'Categoría',
                valor: _categoria,
                opciones: Categoria.values,
                nombreDe: (c) => '${c.nombre} · ${c.volumenPorSesion} · '
                    '${c.sesionesPorSemana} sesiones',
                alCambiar: (valor) => setState(() {
                  if (valor == null) return;
                  _categoria = valor;
                  _fase = valor.usaAtr ? (_fase ?? FaseAtr.acumulacion) : null;
                  _dias = valor.sesionesPorSemana > 7
                      ? (valor.sesionesPorSemana / 2).ceil()
                      : valor.sesionesPorSemana;
                }),
              ),
              CampoDeOpciones<Estilo>(
                etiqueta: 'Estilo objetivo',
                valor: _estilo,
                opciones: const [
                  Estilo.libre,
                  Estilo.espalda,
                  Estilo.pecho,
                  Estilo.mariposa,
                ],
                nombreDe: (e) => e.nombre,
                alCambiar: (valor) =>
                    setState(() => _estilo = valor ?? _estilo),
              ),
              TextField(
                controller: _prueba,
                decoration: const InputDecoration(
                  labelText: 'Prueba objetivo',
                  hintText: '100 Libre',
                ),
              ),
            ],
          ),

          _Bloque(
            titulo: 'La semana',
            children: [
              if (_categoria.usaAtr)
                CampoDeOpciones<FaseAtr>(
                  etiqueta: 'Fase ATR',
                  valor: _fase,
                  opciones: FaseAtr.values,
                  nombreDe: (f) =>
                      '${f.nombre} · ${f.porcentajeTecnico}% técnico',
                  alCambiar: (valor) => setState(() => _fase = valor),
                )
              else
                const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline),
                  title: Text('Esta categoría no usa el modelo ATR'),
                ),
              TextField(
                controller: _componente,
                decoration: const InputDecoration(
                  labelText: 'Componente acentuado de la semana',
                  hintText: 'Técnica de eficiencia, ritmo competitivo…',
                  helperText: 'Da nombre al microciclo. Cambiarlo cambia el '
                      'plan: es lo que hace que dos semanas no salgan iguales.',
                ),
                maxLines: 2,
              ),
              _Numero(
                etiqueta: 'Días disponibles',
                valor: _dias,
                minimo: 1,
                maximo: 7,
                alCambiar: (v) => setState(() => _dias = v),
              ),
              _Numero(
                etiqueta: 'Duración de sesión (minutos)',
                valor: _duracion,
                minimo: 15,
                maximo: 240,
                paso: 15,
                alCambiar: (v) => setState(() => _duracion = v),
              ),
              CampoDeOpciones<int>(
                etiqueta: 'Longitud de piscina',
                valor: _piscina,
                opciones: const [25, 50],
                nombreDe: (m) => '$m m',
                alCambiar: (valor) =>
                    setState(() => _piscina = valor ?? _piscina),
              ),
            ],
          ),

          _Bloque(
            titulo: 'Diagnóstico y limitaciones',
            children: [
              TextField(
                controller: _diagnostico,
                decoration: const InputDecoration(
                  labelText: 'Errores técnicos observados, uno por línea',
                  helperText: 'Sin diagnóstico se sigue la progresión técnica '
                      'estándar. No se inventan errores.',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lesiones,
                decoration: const InputDecoration(
                  labelText: 'Lesiones o limitaciones, una por línea',
                  helperText: 'Se registran y se avisan, pero NO modifican el '
                      'plan: la Biblioteca declara qué corrige cada ejercicio, '
                      'no qué está contraindicado. Adaptarlo es tu criterio.',
                ),
                maxLines: 3,
              ),
            ],
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({
    required this.etiqueta,
    required this.valor,
    required this.minimo,
    required this.maximo,
    required this.alCambiar,
    this.paso = 1,
  });

  final String etiqueta;
  final int valor;
  final int minimo;
  final int maximo;
  final int paso;
  final void Function(int) alCambiar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('$etiqueta: $valor')),
        IconButton(
          onPressed:
              valor - paso >= minimo ? () => alCambiar(valor - paso) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        IconButton(
          onPressed:
              valor + paso <= maximo ? () => alCambiar(valor + paso) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
