import 'package:flutter/material.dart';

import 'theme.dart';

Color orderStatusColor(String status) => switch (status) {
      'PENDING' => SupplierColors.warning,
      'ACCEPTED' => SupplierColors.seed,
      'READY' => SupplierColors.bright,
      'DELIVERED' => SupplierColors.success,
      'REJECTED' => SupplierColors.danger,
      'CANCELLED' => SupplierColors.muted,
      _ => SupplierColors.muted,
    };

String orderStatusLabel(String status) => switch (status) {
      'PENDING' => 'Awaiting review',
      'ACCEPTED' => 'Accepted',
      'READY' => 'Ready for delivery',
      'DELIVERED' => 'Delivered',
      'REJECTED' => 'Rejected',
      'CANCELLED' => 'Cancelled',
      _ => status,
    };

IconData orderStatusIcon(String status) => switch (status) {
      'PENDING' => Icons.hourglass_top_rounded,
      'ACCEPTED' => Icons.check_circle_outline_rounded,
      'READY' => Icons.inventory_rounded,
      'DELIVERED' => Icons.local_shipping_rounded,
      'REJECTED' => Icons.cancel_outlined,
      'CANCELLED' => Icons.block_rounded,
      _ => Icons.receipt_long_outlined,
    };
