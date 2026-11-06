import 'package:flutter/material.dart';

import '../core/theme.dart';

class CatalogPager extends StatelessWidget {
  const CatalogPager({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int pageSize;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  int get pageCount => total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              total == 0
                  ? 'No results'
                  : 'Page $page of $pageCount · $total result${total == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 11.5, color: AdminColors.muted),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
