import 'package:flutter/material.dart';

import '../../../data/models/place.dart';

class PlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const PlaceCard({super.key, required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(place.name),
      subtitle: Text(place.address),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}




