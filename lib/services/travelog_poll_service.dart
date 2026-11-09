import 'package:cloud_functions/cloud_functions.dart';

abstract class TravelogPollGateway {
  Future<Map<String, dynamic>> load();
  Future<void> vote(String pollId, String country);
}

class FirebaseTravelogPollGateway implements TravelogPollGateway {
  @override
  Future<Map<String, dynamic>> load() async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('travelogPoll')
        .call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<void> vote(String pollId, String country) async {
    await FirebaseFunctions.instance.httpsCallable('travelogVote').call({
      'pollId': pollId,
      'choice': country,
    });
  }
}
