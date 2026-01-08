import 'package:flutter/material.dart';

import '../../../data/models/place.dart';
import 'place_card.dart';

class PlaceListSheet extends StatelessWidget {
  final List<Place> places;
  final void Function(Place place) onSelect;

  const PlaceListSheet({
    super.key,
    required this.places,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black26,
            offset: Offset(0, -4),
          )
        ],
      ),
      child: places.isEmpty
          ? const Center(child: Text('주변 결과 없음'))
          : ListView.builder(
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                return PlaceCard(place: place, onTap: () => onSelect(place));
              },
            ),
    );
  }
}




