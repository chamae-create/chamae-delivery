import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/data/order_attempt.dart';

void main() {
  test('restart reads persisted order before allowing a retry write', () async {
    var writes = 0, reads = 0;
    final recovered = OrderAttempt(
        previouslyAttempted: true,
        existsOnServer: () async {
          reads++;
          return true;
        },
        write: () async {
          writes++;
        });
    await recovered.submit();
    expect(reads, 1);
    expect(writes, 0);
  });
  test('double tap shares one write and a confirmed order is never rewritten',
      () async {
    final ack = Completer<void>();
    var writes = 0;
    final attempt = OrderAttempt(
        existsOnServer: () async => false,
        write: () {
          writes++;
          return ack.future;
        });
    final first = attempt.submit(), second = attempt.submit();
    expect(identical(first, second), isTrue);
    ack.complete();
    await Future.wait([first, second]);
    await attempt.submit();
    expect(writes, 1);
  });
  test('lost acknowledgement recovers committed order without duplicate write',
      () async {
    var writes = 0, reads = 0;
    final attempt = OrderAttempt(existsOnServer: () async {
      reads++;
      return true;
    }, write: () async {
      writes++;
      throw TimeoutException('lost ack');
    });
    await expectLater(attempt.submit(), throwsA(isA<TimeoutException>()));
    await attempt.submit();
    expect(writes, 1);
    expect(reads, 1);
  });
  test('failed server lookup prevents another write when result is uncertain',
      () async {
    var writes = 0;
    final attempt = OrderAttempt(
        existsOnServer: () async => throw TimeoutException('offline'),
        write: () async {
          writes++;
          throw TimeoutException('offline');
        });
    await expectLater(attempt.submit(), throwsA(isA<TimeoutException>()));
    await expectLater(attempt.submit(), throwsA(isA<TimeoutException>()));
    expect(writes, 1);
  });
}
