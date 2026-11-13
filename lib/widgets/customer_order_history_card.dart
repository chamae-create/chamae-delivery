import 'package:flutter/material.dart';
import '../l10n/customer_localizations.dart';
/// Presentation only: immutable IDs and monetary strings are never translated.
class CustomerOrderHistoryCard extends StatelessWidget {
  final String id, total, status;
  final DateTime date;
  final VoidCallback onTap;
  const CustomerOrderHistoryCard({super.key,required this.id,required this.total,
    required this.status,required this.date,required this.onTap});
  @override Widget build(BuildContext context)=>Card(elevation:0,child:ListTile(
    isThreeLine:true,title:Text(id,style:const TextStyle(fontWeight:FontWeight.w700)),
    subtitle:Text('${localizedDate(context,date)} • R\$ $total\n${localizedLabel(context,status)}'),
    trailing:const Icon(Icons.chevron_right),onTap:onTap));
}
