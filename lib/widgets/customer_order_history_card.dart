import 'package:flutter/material.dart';

/// Shared presentation; account authorization and order loading stay in screen.
class CustomerOrderHistoryCard extends StatelessWidget {
  final String id, total, status;
  final DateTime date;
  final VoidCallback onTap;
  const CustomerOrderHistoryCard(
      {super.key,
      required this.id,
      required this.total,
      required this.status,
      required this.date,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      child: ListTile(
        isThreeLine: true,
        title: Text(id, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${date.day}/${date.month}/${date.year} • R\$ $total\n$status'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ));
}
