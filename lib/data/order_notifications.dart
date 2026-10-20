enum OrderNotificationPermission { granted, denied, unavailable }

/// Permission is requested only after the customer chooses updates for an order.
/// The real platform adapter also binds its token to the authenticated owner.
abstract class OrderNotifications {
  Future<OrderNotificationPermission> requestForOrder(String orderId);
}

class UnconfiguredOrderNotifications implements OrderNotifications {
  const UnconfiguredOrderNotifications();
  @override
  Future<OrderNotificationPermission> requestForOrder(String orderId) async =>
      OrderNotificationPermission.unavailable;
}
