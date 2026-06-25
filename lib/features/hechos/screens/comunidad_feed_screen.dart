import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hecho_model.dart';
import '../controllers/hechos_controller.dart';
import 'hecho_detalle_screen.dart';
import '../../../core/widgets/pendientes_banner.dart';

class ComunidadFeedScreen extends StatefulWidget {
  final HechosController controlador;

  const ComunidadFeedScreen({super.key, required this.controlador});

  @override
  State<ComunidadFeedScreen> createState() => _ComunidadFeedScreenState();
}

class _ComunidadFeedScreenState extends State<ComunidadFeedScreen> {
  // --- VARIABLES DEL MOTOR DE FILTROS ---
  String _filtroEstado = 'Todos'; // Todos, Activos, Resueltos
  String _filtroTiempo = 'Siempre'; // Siempre, Hoy, Semana, Mes
  String _filtroCategoria = 'Todas'; // Todas, Bache, Basura...

  // Lazy loading: tarjetas renderizadas; crece al hacer scroll.
  static const int _tamanoPagina = 8;
  int _itemsVisibles = _tamanoPagina;
  int _totalFiltrado = 0;
  final ScrollController _scrollController = ScrollController();

  final List<String> _categorias = [
    'Todas',
    'Bache',
    'Basura',
    'Luminaria',
    'Agua / Caño',
    'Accidente',
    'Obstrucción',
    'Inseguridad',
    'Otro',
  ];
  bool get _hayFiltrosActivos =>
      _filtroEstado != 'Todos' ||
      _filtroTiempo != 'Siempre' ||
      _filtroCategoria != 'Todas';

  // Extrae la categoría real del texto [Categoría] - Descripción
  String _extraerCategoria(String descripcion, String tipoBackend) {
    final match = RegExp(r'^\[(.*?)\] - (.*)$').firstMatch(descripcion);
    if (match != null) return match.group(1) ?? 'Otro';
    return tipoBackend == 'problema' ? 'Problema' : 'Alerta';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_alScrollear);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_alScrollear);
    _scrollController.dispose();
    super.dispose();
  }

  void _alScrollear() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        _itemsVisibles < _totalFiltrado) {
      setState(() => _itemsVisibles += _tamanoPagina);
    }
  }

  Future<void> _refrescarFeed() async {
    await widget.controlador.cargarHechos();
    if (mounted) setState(() => _itemsVisibles = _tamanoPagina);
  }

  void _abrirPanelFiltrosAvanzados() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // StatefulBuilder permite actualizar el panel interno sin recargar el fondo
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Filtros Avanzados',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 1. FILTRO DE ESTADO
                    Text(
                      'ESTADO DEL REPORTE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: ['Todos', 'Activos', 'Resueltos'].map((estado) {
                        final isSelected = _filtroEstado == estado;
                        return ChoiceChip(
                          label: Text(
                            estado,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.blueGrey[700],
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val)
                              setModalState(() => _filtroEstado = estado);
                            setState(() {}); // Actualiza la lista detrás
                          },
                          selectedColor: AppColors.azulPrimario,
                          backgroundColor: Colors.grey[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // 2. FILTRO DE TIEMPO
                    Text(
                      'ANTIGÜEDAD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ['Siempre', 'Hoy', 'Semana', 'Mes'].map((
                        tiempo,
                      ) {
                        final isSelected = _filtroTiempo == tiempo;
                        return ChoiceChip(
                          label: Text(
                            tiempo == 'Semana'
                                ? 'Últimos 7 días'
                                : tiempo == 'Mes'
                                ? 'Últimos 30 días'
                                : tiempo,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.blueGrey[700],
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val)
                              setModalState(() => _filtroTiempo = tiempo);
                            setState(() {});
                          },
                          selectedColor: AppColors.azulPrimario,
                          backgroundColor: Colors.grey[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // BOTÓN APLICAR / LIMPIAR
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _filtroEstado = 'Todos';
                              _filtroTiempo = 'Siempre';
                              _filtroCategoria = 'Todas';
                            });
                            setState(() {});
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Limpiar',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.azulPrimario,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Ver Resultados',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEstadoError() {
    return SafeArea(
      child: Column(
        children: [
          // Banner de reportes offline: visible incluso sin conexión.
          // (se auto-oculta si la cola está vacía)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: PendientesBanner(),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 60,
                      color: Colors.blueGrey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pudimos cargar los reportes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Revisá tu conexión e intentá de nuevo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueGrey[500]),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => widget.controlador.cargarHechos(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.azulPrimario,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controlador,
      builder: (context, child) {
        if (widget.controlador.estaCargando &&
            widget.controlador.hechosActivos.isEmpty) {
          return Container(
            color: const Color(0xFFF4F7FB),
            child: const _FeedSkeleton(),
          );
        }

        if (widget.controlador.mensajeError != null &&
            widget.controlador.hechosActivos.isEmpty) {
          return _buildEstadoError();
        }

        // MOTOR MULTI-CRITERIO: Filtramos la lista combinando los 3 filtros
        final hechosFiltrados =
            widget.controlador.hechosActivos.where((hecho) {
              // Ignoramos siempre los positivos
              if (hecho.tipoHecho == 'positivo') return false;

              // 1. Filtro de Estado
              if (_filtroEstado == 'Activos' && hecho.estado == 'resuelto')
                return false;
              if (_filtroEstado == 'Resueltos' && hecho.estado != 'resuelto')
                return false;

              // 2. Filtro de Tiempo
              final diasAntiguedad = DateTime.now()
                  .difference(hecho.creadoEn)
                  .inDays;
              if (_filtroTiempo == 'Hoy' && diasAntiguedad > 1) return false;
              if (_filtroTiempo == 'Semana' && diasAntiguedad > 7) return false;
              if (_filtroTiempo == 'Mes' && diasAntiguedad > 30) return false;

              // 3. Filtro de Categoría (Usando nuestra inteligencia de parseo)
              if (_filtroCategoria != 'Todas') {
                final categoriaReal = _extraerCategoria(
                  hecho.descripcion ?? '',
                  hecho.tipoHecho,
                );
                if (categoriaReal != _filtroCategoria) return false;
              }

              return true;
            }).toList()..sort(
              (a, b) => b.creadoEn.compareTo(a.creadoEn),
            ); // Orden reciente primero
        _totalFiltrado = hechosFiltrados.length;
        // Contador de filtros activos (para mostrar indicador numérico)
        int filtrosActivosCount = 0;
        if (_filtroEstado != 'Todos') filtrosActivosCount++;
        if (_filtroTiempo != 'Siempre') filtrosActivosCount++;

        return Container(
          color: const Color(0xFFF4F7FB),
          child: RefreshIndicator(
            onRefresh: _refrescarFeed,
            color: AppColors.azulPrimario,
            edgeOffset: 110,
            displacement: 40,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // CABECERA
                SliverPadding(
                  padding: const EdgeInsets.only(
                    top: 110,
                    left: 24,
                    right: 24,
                    bottom: 16,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Descubre',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.azulPrimario.withOpacity(0.8),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Caleta Olivia',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.blueGrey[900],
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Explora el historial de reportes comunitarios.',
                          style: TextStyle(
                            color: Colors.blueGrey[500],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Fase 5: reportes offline pendientes / retenidos
                const SliverToBoxAdapter(child: PendientesBanner()),

                // BARRA DE ACCESO RÁPIDO A CATEGORÍAS Y FILTROS
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      // +1 para incluir el botón de filtros al inicio
                      itemCount: _categorias.length + 1,
                      itemBuilder: (context, index) {
                        // Botón Avanzado (Siempre primero)
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: ActionChip(
                              avatar: Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: filtrosActivosCount > 0
                                    ? Colors.white
                                    : AppColors.azulPrimario,
                              ),
                              label: Text(
                                filtrosActivosCount > 0
                                    ? 'Filtros ($filtrosActivosCount)'
                                    : 'Filtros',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: filtrosActivosCount > 0
                                      ? Colors.white
                                      : AppColors.azulPrimario,
                                ),
                              ),
                              backgroundColor: filtrosActivosCount > 0
                                  ? AppColors.azulPrimario
                                  : AppColors.azulPrimario.withOpacity(0.1),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onPressed: _abrirPanelFiltrosAvanzados,
                            ),
                          );
                        }

                        // Categorías Rápidas
                        final categoria = _categorias[index - 1];
                        final isSelected = _filtroCategoria == categoria;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              categoria,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.blueGrey[600],
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected)
                                setState(() => _filtroCategoria = categoria);
                            },
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.azulPrimario,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.azulPrimario
                                    : Colors.blueGrey[100]!,
                                width: 1.5,
                              ),
                            ),
                            elevation: isSelected ? 4 : 0,
                            shadowColor: AppColors.azulPrimario.withOpacity(
                              0.4,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),

                // ESTADO VACÍO MULTI-FILTRO
                if (hechosFiltrados.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.manage_search_rounded,
                              size: 60,
                              color: Colors.blueGrey[200],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _hayFiltrosActivos
                                ? 'Sin resultados'
                                : 'Todo tranquilo por acá',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hayFiltrosActivos
                                ? 'No hay reportes que coincidan con estos filtros.'
                                : 'Aún no hay reportes en tu zona. ¡Sé el primero en publicar uno!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.blueGrey[500]),
                          ),
                          const SizedBox(height: 16),
                          if (_hayFiltrosActivos)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _filtroEstado = 'Todos';
                                  _filtroTiempo = 'Siempre';
                                  _filtroCategoria = 'Todas';
                                });
                              },
                              icon: const Icon(Icons.clear_all_rounded),
                              label: const Text('Limpiar todos los filtros'),
                            ),
                        ],
                      ),
                    ),
                  )
                // LISTA DE TARJETAS
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 120,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => HechoCard(
                          hecho: hechosFiltrados[index],
                          controlador: widget.controlador,
                        ),
                        childCount: _itemsVisibles < hechosFiltrados.length
                            ? _itemsVisibles
                            : hechosFiltrados.length,
                      ),
                    ),
                  ),
                if (_itemsVisibles < hechosFiltrados.length)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.azulPrimario,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// WIDGET: TARJETA DE REPORTE PREMIUM (Se mantiene tu compresión CacheWidth)
// ============================================================================
class HechoCard extends StatelessWidget {
  final HechoModel hecho;
  final HechosController controlador;

  const HechoCard({super.key, required this.hecho, required this.controlador});

  Map<String, String> _parsearDescripcion() {
    String descRaw = hecho.descripcion ?? '';
    final match = RegExp(r'^\[(.*?)\] - (.*)$').firstMatch(descRaw);
    if (match != null) {
      return {
        'categoria': match.group(1) ?? 'Reporte',
        'descripcion': match.group(2) ?? '',
      };
    }
    String catFallback = hecho.tipoHecho == 'problema' ? 'Problema' : 'Alerta';
    return {'categoria': catFallback, 'descripcion': descRaw};
  }

  Map<String, dynamic> _getEstilosCategoria(String categoria) {
    switch (categoria) {
      case 'Bache':
        return {'icono': Icons.terrain_rounded, 'color': Colors.red[500]};
      case 'Basura':
        return {
          'icono': Icons.delete_outline_rounded,
          'color': Colors.brown[400],
        };
      case 'Luminaria':
        return {
          'icono': Icons.lightbulb_outline_rounded,
          'color': Colors.amber[600],
        };
      case 'Agua / Caño':
        return {'icono': Icons.water_drop_outlined, 'color': Colors.blue[500]};
      case 'Accidente':
        return {
          'icono': Icons.car_crash_outlined,
          'color': Colors.deepOrange[500],
        };
      case 'Obstrucción':
        return {'icono': Icons.block_flipped, 'color': Colors.orange[500]};
      case 'Inseguridad':
        return {'icono': Icons.security_outlined, 'color': Colors.purple[400]};
      default:
        return hecho.tipoHecho == 'alerta'
            ? {'icono': Icons.warning_rounded, 'color': Colors.orange[500]}
            : {
                'icono': Icons.report_problem_rounded,
                'color': Colors.blueGrey[500],
              };
    }
  }

  String _tiempoTranscurrido(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inDays > 7)
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    if (diferencia.inDays > 0) return 'Hace ${diferencia.inDays}d';
    if (diferencia.inHours > 0) return 'Hace ${diferencia.inHours}h';
    if (diferencia.inMinutes > 0) return 'Hace ${diferencia.inMinutes}m';
    return 'Justo ahora';
  }

  @override
  Widget build(BuildContext context) {
    final esBurbuja = hecho.tipoHecho == 'comunitario';
    final parseado = _parsearDescripcion();
    final categoriaNombre = parseado['categoria']!;
    final descripcionLimpia = parseado['descripcion']!;

    final estilosUI = _getEstilosCategoria(categoriaNombre);
    final bool esResuelto = hecho.estado == 'resuelto';
    final Color colorUI = esResuelto
        ? Colors.green[600]!
        : estilosUI['color'] as Color;
    final IconData iconoUI = esResuelto
        ? Icons.verified_rounded
        : estilosUI['icono'] as IconData;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HechoDetalleScreen(hecho: hecho, controller: controlador),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorUI.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(iconoUI, size: 14, color: colorUI),
                            const SizedBox(width: 6),
                            Text(
                              esResuelto
                                  ? 'RESUELTO • ${categoriaNombre.toUpperCase()}'
                                  : categoriaNombre.toUpperCase(),
                              style: TextStyle(
                                color: colorUI,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _tiempoTranscurrido(hecho.creadoEn),
                        style: TextStyle(
                          color: Colors.blueGrey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    descripcionLimpia.isNotEmpty
                        ? descripcionLimpia
                        : 'Reporte en la zona',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.blueGrey[900],
                      height: 1.3,
                    ),
                    maxLines: esBurbuja ? null : 3,
                    overflow: esBurbuja
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                  if (hecho.direccion != null &&
                      hecho.direccion!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: Colors.blueGrey[400],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hecho.direccion!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blueGrey[500],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (!esBurbuja &&
                hecho.fotoUrl != null &&
                hecho.fotoUrl!.isNotEmpty)
              Container(
                width: double.infinity,
                height: 220,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          hecho.fotoUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 800, // RAM Optimization intact
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[100],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                        ),
                      ),

                      // SELLO DE TRANSPARENCIA (Capa 2) sobre la foto
                      if (hecho.origenFoto != null)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: hecho.origenFoto == 'en_vivo'
                                  ? Colors.black.withOpacity(0.55)
                                  : Colors.orange[900]!.withOpacity(0.78),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hecho.origenFoto == 'en_vivo'
                                      ? Icons.photo_camera_rounded
                                      : Icons.gpp_maybe_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hecho.origenFoto == 'en_vivo'
                                      ? 'En el lugar'
                                      : 'Sin verificar en el lugar',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blueGrey[50],
                    backgroundImage:
                        hecho.avatarAutor != null &&
                            hecho.avatarAutor!.isNotEmpty
                        ? NetworkImage(hecho.avatarAutor!)
                        : null,
                    child:
                        hecho.avatarAutor == null || hecho.avatarAutor!.isEmpty
                        ? Icon(
                            Icons.person,
                            color: Colors.blueGrey[300],
                            size: 18,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hecho.nombreAutor ?? 'Ciudadano',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.blueGrey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: Colors.blueGrey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${hecho.conteoUpvotes}',
                          style: TextStyle(
                            color: Colors.blueGrey[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 15,
                          color: Colors.blueGrey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${hecho.conteoComentarios}',
                          style: TextStyle(
                            color: Colors.blueGrey[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedSkeleton extends StatefulWidget {
  const _FeedSkeleton();
  @override
  State<_FeedSkeleton> createState() => _FeedSkeletonState();
}

class _FeedSkeletonState extends State<_FeedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box({double? width, double height = 14, double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.blueGrey[100],
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _card() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _box(width: 80, height: 12),
              const Spacer(),
              _box(width: 50, height: 12),
            ],
          ),
          const SizedBox(height: 12),
          _box(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          _box(width: 180, height: 16),
          const SizedBox(height: 14),
          _box(width: double.infinity, height: 180, radius: 16),
          const SizedBox(height: 14),
          Row(
            children: [
              _box(width: 36, height: 36, radius: 18),
              const SizedBox(width: 10),
              _box(width: 100, height: 12),
              const Spacer(),
              _box(width: 60, height: 12),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_ctrl),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 120, 20, 20),
        physics: const NeverScrollableScrollPhysics(),
        children: [_card(), _card(), _card()],
      ),
    );
  }
}
