import 'dart:async';

/// Async scope captures account and consent revision for a device read job.
/// Each subsequent plugin query checks that scope again after any awaits.
const _healthReadGuardKey = #healthReadGuard;
bool get healthReadAllowed =>
    (Zone.current[_healthReadGuardKey] as bool Function()?)?.call() ?? false;

Future<T> withHealthReadConsent<T>(
        bool Function() allowed, Future<T> Function() read) =>
    runZoned(read, zoneValues: {_healthReadGuardKey: allowed});
