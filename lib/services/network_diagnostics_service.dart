// lib/services/network_diagnostics_service.dart
import 'dart:async';
import 'dart:io';

class DnsLookupResult {
  final String hostname;
  final List<String> addresses;
  final int elapsedMs;
  final String? error;

  const DnsLookupResult({
    required this.hostname,
    required this.addresses,
    required this.elapsedMs,
    this.error,
  });
}

class PortCheckResult {
  final String host;
  final int port;
  final bool isOpen;
  final int latencyMs;
  final String? banner;

  const PortCheckResult({
    required this.host,
    required this.port,
    required this.isOpen,
    required this.latencyMs,
    this.banner,
  });
}

class SpeedEstimateResult {
  final double downloadMbps;
  final int latencyMs;
  final String? error;

  const SpeedEstimateResult({
    required this.downloadMbps,
    required this.latencyMs,
    this.error,
  });
}

class NetworkDiagnosticsService {
  /// Perform DNS hostname resolution and measure lookup latency.
  Future<DnsLookupResult> resolveDns(String host) async {
    final sw = Stopwatch()..start();
    try {
      final records = await InternetAddress.lookup(host);
      sw.stop();
      final addrs = records.map((r) => r.address).toList();
      return DnsLookupResult(
        hostname: host,
        addresses: addrs,
        elapsedMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      return DnsLookupResult(
        hostname: host,
        addresses: const [],
        elapsedMs: sw.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  /// Probe a single TCP port for connectivity and grab banner if returned.
  Future<PortCheckResult> checkPort(String host, int port, {int timeoutMs = 1500}) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: Duration(milliseconds: timeoutMs));
      sw.stop();

      String? banner;
      try {
        final completer = Completer<String?>();
        socket.listen(
          (data) {
            if (!completer.isCompleted) {
              completer.complete(String.fromCharCodes(data).trim());
            }
          },
          onError: (_) {
            if (!completer.isCompleted) completer.complete(null);
          },
        );
        banner = await completer.future.timeout(const Duration(milliseconds: 300), onTimeout: () => null);
      } catch (_) {}

      socket.destroy();
      return PortCheckResult(
        host: host,
        port: port,
        isOpen: true,
        latencyMs: sw.elapsedMilliseconds,
        banner: banner,
      );
    } catch (_) {
      sw.stop();
      socket?.destroy();
      return PortCheckResult(
        host: host,
        port: port,
        isOpen: false,
        latencyMs: sw.elapsedMilliseconds,
      );
    }
  }

  /// Estimate local network download throughput by requesting a known small test payload from gateway / local server.
  Future<SpeedEstimateResult> estimateSpeed(String targetUrl) async {
    final sw = Stopwatch();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..badCertificateCallback = (_, __, ___) => true;
    try {
      final uri = Uri.parse(targetUrl);
      sw.start();
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode >= 400) {
        sw.stop();
        return SpeedEstimateResult(
          downloadMbps: 0,
          latencyMs: sw.elapsedMilliseconds,
          error: 'HTTP ${resp.statusCode}',
        );
      }
      int bytesReceived = 0;
      await for (final chunk in resp) {
        bytesReceived += chunk.length;
      }
      sw.stop();

      final seconds = sw.elapsedMilliseconds / 1000.0;
      if (seconds <= 0) {
        return const SpeedEstimateResult(downloadMbps: 0, latencyMs: 0, error: 'Measurement invalid');
      }
      final bits = bytesReceived * 8;
      final mbps = (bits / 1e6) / seconds;
      return SpeedEstimateResult(
        downloadMbps: mbps,
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      return SpeedEstimateResult(
        downloadMbps: 0,
        latencyMs: sw.elapsedMilliseconds,
        error: e.toString(),
      );
    } finally {
      client.close();
    }
  }
}
