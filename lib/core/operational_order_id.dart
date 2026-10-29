/// A public server-issued label. Never use this value as authorization or doc ID.
String customerOrderLabel(Map<String, dynamic> data,
    [String fallback = 'Código em preparação']) {
  final code = data['displayOrderId'];
  if (code is String &&
      RegExp(r'^V8-(?:[0-9]{4}|[1-9][0-9]{4,})$').hasMatch(code) &&
      code != 'V8-0000') {
    return code;
  }
  return data['id'] is String ? data['id'] as String : fallback;
}
