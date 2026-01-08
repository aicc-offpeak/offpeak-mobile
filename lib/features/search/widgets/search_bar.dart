import 'package:flutter/material.dart';

import '../../../core/utils/debouncer.dart';

class SearchBarWidget extends StatefulWidget {
  final void Function(String value) onSubmit;

  const SearchBarWidget({super.key, required this.onSubmit});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final controller = TextEditingController();
  final debouncer = Debouncer(delay: const Duration(milliseconds: 300));

  @override
  void dispose() {
    controller.dispose();
    debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: '장소를 검색하세요',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => debouncer.run(() => widget.onSubmit(value)),
        onSubmitted: widget.onSubmit,
      ),
    );
  }
}




