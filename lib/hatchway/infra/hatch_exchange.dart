import 'dart:convert';

import '../config/era_hatch_config.dart';
import '../core/hatch_models.dart';
import 'flight_attribution.dart';
import 'nest_vault.dart';
import 'roost_agent.dart';

class HatchExchange {
  HatchExchange(this._agent, this._vault);

  final RoostAgent _agent;
  final NestVault _vault;

  Future<HatchReply> request(Map<String, dynamic> payload) async {
    if (!EraHatchConfig.grayCredentialsReady) {
      return HatchReply.rejected('credentials_unavailable');
    }
    try {
      dashTrace(() => '[DASH.YOLK] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(EraHatchConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      dashTrace(
        () => '[DASH.YOLK] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return HatchReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return HatchReply.rejected('invalid_response');
      final reply = HatchReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      dashTrace(() => '[DASH.YOLK] failed: $error');
      return HatchReply.rejected('network_failure');
    }
  }
}
