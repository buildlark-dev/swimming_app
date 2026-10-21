/// Pantalla de perfiles de nadador.
///
/// Señala los datos obligatorios que faltan: categoría y estilo objetivo, sin
/// los cuales no se puede validar ni el volumen ni la distribución de estilos.
library;

import 'package:flutter/material.dart';
import 'package:natacion_app/ui/tema/avisos.dart';
import 'package:natacion_app/dominio/entidades/nadador.dart';
import 'package:natacion_app/dominio/metodologia/categorias.dart';
import 'package:natacion_app/dominio/metodologia/estilos.dart';
import 'package:natacion_app/dominio/repositorios/repositorios.dart';
import 'package:natacion_app/ui/componentes/campo.dart';
import 'package:natacion_app/ui/componentes/estado_vacio.dart';

class PantallaPerfiles extends StatefulWidget {
  const PantallaPerfiles({super.key, required this.repositorio});

  final RepositorioNadadores repositorio;

  @override
  State<PantallaPerfiles> createState() => _PantallaPerfilesState();
}

class _PantallaPerfilesState extends State<PantallaPerfiles> {
  List<Nadador> _nadadores = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  Future<void> _recargar() async {
    final nadadores = await widget.repositorio.listar();
    if (!mounted) return;
    setState(() {
      _nadadores = nadadores;
      _cargando = false;
    });
  }

  Future<void> _nuevoPerfil() async {
    final nadador = await showDialog<Nadador>(
      context: context,
      builder: (_) => const _DialogoPerfil(),
    );
    if (nadador == null) return;

    await widget.repositorio.guardar(nadador);
    await _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nadadores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoPerfil,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo perfil'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_nadadores.isEmpty)
                  const EstadoVacio(
                    icono: Icons.group_outlined,
                    titulo: 'Todavía no hay perfiles',
                    queHacer: 'Crea el primero con el botón «Nuevo perfil».',
                  ),
                for (final nadador in _nadadores)
                  _TarjetaPerfil(nadador: nadador),
              ],
            ),
    );
  }
}

class _TarjetaPerfil extends StatelessWidget {
  const _TarjetaPerfil({required this.nadador});

  final Nadador nadador;

  @override
  Widget build(BuildContext context) {
    final faltas = nadador.faltas;

    return Card(
      child: ListTile(
        // **Informativo, no error.** Un perfil al que le falta la categoría
        // no es un fallo: es un perfil a medio llenar, que es como empiezan
        // todos. Lo que hace falta es que se vea, no que asuste (FR-016).
        leading: Icon(
          nadador.estaCompleto ? Icons.person : Icons.person_outline,
          color: nadador.estaCompleto ? null : context.colores.informativo,
        ),
        title: Text(nadador.nombre.isEmpty ? 'Sin nombre' : nadador.nombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (nadador.categoria != null) nadador.categoria!.nombre,
                if (nadador.estiloObjetivo != null)
                  nadador.estiloObjetivo!.nombre,
                if (nadador.pruebaObjetivo.isNotEmpty) nadador.pruebaObjetivo,
              ].join(' · '),
            ),
            for (final falta in faltas)
              Text(
                falta.descripcion,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colores.informativo,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DialogoPerfil extends StatefulWidget {
  const _DialogoPerfil();

  @override
  State<_DialogoPerfil> createState() => _DialogoPerfilState();
}

class _DialogoPerfilState extends State<_DialogoPerfil> {
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _prueba = TextEditingController();
  Categoria? _categoria;
  Estilo? _estilo;

  @override
  void dispose() {
    _nombre.dispose();
    _prueba.dispose();
    super.dispose();
  }

  Nadador get _nadador => Nadador(
        nombre: _nombre.text.trim(),
        categoria: _categoria,
        estiloObjetivo: _estilo,
        pruebaObjetivo: _prueba.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final faltas = _nadador.faltas;

    return AlertDialog(
      title: const Text('Nuevo perfil'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Campo(
              etiqueta: 'Nombre',
              controlador: _nombre,
              alCambiar: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            CampoDeOpciones<Categoria>(
              etiqueta: 'Categoría',
              valor: _categoria,
              opciones: Categoria.values,
              nombreDe: (c) => c.nombre,
              alCambiar: (valor) => setState(() => _categoria = valor),
            ),
            const SizedBox(height: 8),
            CampoDeOpciones<Estilo>(
              etiqueta: 'Estilo objetivo',
              valor: _estilo,
              opciones: const [
                Estilo.libre,
                Estilo.espalda,
                Estilo.pecho,
                Estilo.mariposa,
                Estilo.combinado,
              ],
              nombreDe: (e) => e.nombre,
              alCambiar: (valor) => setState(() => _estilo = valor),
            ),
            const SizedBox(height: 8),
            Campo(
              etiqueta: 'Prueba objetivo',
              controlador: _prueba,
              pista: '100 Libre',
            ),
            const SizedBox(height: 12),
            for (final falta in faltas)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  falta.descripcion,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colores.informativo,
                      ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              faltas.isEmpty ? () => Navigator.of(context).pop(_nadador) : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
