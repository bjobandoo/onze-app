import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/onze_dock.dart';

/// Shell de navegación principal: monta el dock flotante sobre las
/// seis pestañas raíz (Inicio, Canchas, Desafíos, Equipo, Ranking, Perfil).
///
/// Las pantallas de detalle viven fuera del shell, por lo que cubren
/// el dock al navegar hacia ellas.
class OnzeShell extends StatelessWidget {
  const OnzeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<OnzeDockItem> _items = [
    OnzeDockItem(icon: Icons.home_outlined, label: 'Inicio'),
    OnzeDockItem(icon: Icons.stadium_outlined, label: 'Canchas'),
    OnzeDockItem(icon: Icons.sports_soccer_outlined, label: 'Desafíos'),
    OnzeDockItem(icon: Icons.group_outlined, label: 'Equipo'),
    OnzeDockItem(icon: Icons.emoji_events_outlined, label: 'Ranking'),
    OnzeDockItem(icon: Icons.person_outline, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: OnzeDock(
        items: _items,
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
