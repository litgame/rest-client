import 'dart:convert';

import 'package:rest_client/rest_client.dart';

import 'exceptions.dart';
import 'models/card.dart';
import 'models/card_collection.dart';

export 'exceptions.dart';
export 'models/error.dart';

class GameClient {
  GameClient(this._baseUrl, [this._idPrefix = '']) : _client = Client();
  String _baseUrl;
  String _idPrefix;
  final Client _client;

  Future<Response> _get(String url) async {
    final request = Request(url: _baseUrl + '$url');

    try {
      return await _client.execute(request: request);
    } on RestException catch (error) {
      throw ValidationException(
          error.response.body['error'], error.response.body['type']);
    }
  }

  Future<Response> _put(String url, Map<String, dynamic> body) async {
    final request = Request(
        url: _baseUrl + '$url', method: RequestMethod.put, body: body.toJson());

    try {
      return await _client.execute(request: request);
    } on RestException catch (error) {
      if (error.response.body == null) rethrow;
      throw ValidationException(
          error.response.body['error'], error.response.body['type']);
    }
  }

  String _addPrefix(String source) {
    if (!source.startsWith(_idPrefix)) {
      return _idPrefix + source;
    }
    return source;
  }

  Future<String> get version async {
    final response = await _get('/version');
    return response.body['version'];
  }

  Future<List<CardCollection>> get collections async {
    final response = await _get('/api/collection/list');

    if (response.body['collections'] == null) throw 'Invalid response format';

    final result = <CardCollection>[];
    for (var collection in response.body['collections']) {
      result.add(CardCollection.fromJson(collection));
    }
    return result;
  }

  Future<Map<String, dynamic>> get games async {
    final response = await _get('/api/game/list');

    if (response.body['games'] == null) throw 'Invalid response format';

    return response.body['games'];
  }

  /// throws [ErrorType.exists]
  Future<String> startGame(String gameId, String adminId) async {
    gameId = _addPrefix(gameId);
    adminId = _addPrefix(adminId);
    final response =
        await _put('/api/game/start', {'gameId': gameId, 'adminId': adminId});

    if (response.body['gameId'] == null)
      throw FatalException('Invalid response format');
    if (response.body['status'].toString() != 'started')
      throw FatalException('Invalid game state');
    return response.body['gameId'].toString();
  }

  /// throws [ErrorType.access]
  Future<bool> endGame(String gameId, String triggeredBy) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    final response = await _put(
        '/api/game/end', {'gameId': gameId, 'triggeredBy': triggeredBy});
    if (response.body['gameId'] == null)
      throw FatalException('Invalid response format');
    if (response.body['status'].toString() != 'finished') return false;
    return true;
  }

  /// throws [ErrorType.exists], [ErrorType.anotherGame]
  Future<bool> join(String gameId, String triggeredBy) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    final response = await _put(
        '/api/game/join', {'gameId': gameId, 'triggeredBy': triggeredBy});
    if (response.body['userId'].toString() != triggeredBy)
      throw FatalException('Invalid response format');
    if (response.body['joined'].toString() != 'true') return false;
    return true;
  }

  /// throws [ErrorType.notFound], [ErrorType.access]
  Future<KickResult> kick(
      String gameId, String triggeredBy, String targetUserId) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    targetUserId = _addPrefix(targetUserId);
    final response = await _put('/api/game/kick', {
      'gameId': gameId,
      'triggeredBy': triggeredBy,
      'targetUserId': targetUserId
    });

    if (response.body['gameId'].toString() == gameId &&
        response.body['status'].toString() == 'finished') {
      return KickResult(true, gameStopped: true);
    }

    if (response.body['userId'] == null)
      throw FatalException('Invalid response format');
    final kicked = response.body['userId'].toString();
    if (kicked != targetUserId)
      throw FatalException('Another user was kicked: $kicked');

    var newMaster;
    var newAdmin;
    var nextTurnBy;
    if (response.body['newMaster'] != null) {
      newMaster = response.body['newMaster'].toString();
    }
    if (response.body['newAdmin'] != null) {
      newMaster = response.body['newAdmin'].toString();
    }
    if (response.body['nextTurnByUserId'] != null) {
      nextTurnBy = response.body['nextTurnByUserId'].toString();
    }

    return KickResult(true,
        newAdminId: newAdmin,
        newMasterId: newMaster,
        nextTurnByUserId: nextTurnBy);
  }

  /// throws [ErrorType.access], [ErrorType.state]
  Future<void> finishJoin(String gameId, String triggeredBy) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    final response = await _put(
        '/api/game/finishJoin', {'gameId': gameId, 'triggeredBy': triggeredBy});
    if (response.body['gameId'].toString() != gameId)
      throw FatalException('Invalid response format');

    if (response.body['state'].toString() != 'sorting')
      throw FatalException('Invalid state!');
  }

  /// throws [ErrorType.notFound], [ErrorType.access]
  Future<bool> setMaster(
      String gameId, String triggeredBy, String targetUserId) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    targetUserId = _addPrefix(targetUserId);
    final response = await _put('/api/game/setMaster', {
      'gameId': gameId,
      'triggeredBy': triggeredBy,
      'targetUserId': targetUserId
    });
    if (response.body['gameId'].toString() != gameId)
      throw FatalException('Invalid response format');

    if (response.body['newMaster'].toString() != targetUserId) return false;

    return true;
  }

  /// throws [ErrorType.access], [ErrorType.notFound]
  Future<int> sortPlayer(String gameId, String triggeredBy, String targetUserId,
      int position) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    targetUserId = _addPrefix(targetUserId);
    final response = await _put('/api/game/sortPlayer', {
      'gameId': gameId,
      'triggeredBy': triggeredBy,
      'targetUserId': targetUserId,
      'position': position
    });
    if (response.body['gameId'].toString() != gameId ||
        response.body['playerPosition'] == null)
      throw FatalException('Invalid response format');

    return int.parse(response.body['playerPosition'].toString());
  }

  /// throws [ErrorType.access], [ErrorType.notFound]
  Future<void> sortReset(String gameId, String triggeredBy) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    final response = await _put(
        '/api/game/sortReset', {'gameId': gameId, 'triggeredBy': triggeredBy});
    if (response.body['gameId'].toString() != gameId)
      throw FatalException('Invalid response format');
  }

  /// throws [ErrorType.access], [ErrorType.state], [ErrorType.validation]
  Future<bool> startTrainingFlow(String gameId, String triggeredBy,
      {String collectionName = 'default', String? collectionId}) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    var params = {
      'gameId': gameId,
      'triggeredBy': triggeredBy,
      'collectionName': collectionName
    };
    if (collectionId != null) {
      params['collectionId'] = collectionId;
    }
    final response = await _put('/api/game/training/start', params);
    if (response.body['gameId'].toString() != gameId)
      throw FatalException('Invalid response format');

    if (response.body['state'].toString() != 'training') return false;

    return true;
  }

  /// throws [ErrorType.state], [ErrorType.validation]
  Future<Map<String, Card>> trainingFlowNextTurn(
      String gameId, String triggeredBy) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    final response = await _put('/api/game/training/next',
        {'gameId': gameId, 'triggeredBy': triggeredBy});
    if (response.body['gameId'].toString() != gameId ||
        response.body['card'] == null ||
        response.body['playerId'] == null)
      throw FatalException('Invalid response format');

    final card = Card.fromJson(response.body['card']);

    return {response.body['playerId'].toString(): card};
  }

  /// throws [ErrorType.access], [ErrorType.state], [ErrorType.validation]
  Future<List<Card>> startGameFlow(String gameId, String triggeredBy) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    final response = await _put(
        '/api/game/game/start', {'gameId': gameId, 'triggeredBy': triggeredBy});
    if (response.body['gameId'].toString() != gameId ||
        response.body['state'].toString() != 'game' ||
        response.body['flowState'].toString() != 'storyTell')
      throw FatalException('Invalid response format');

    if (response.body['initialCards'] == null)
      throw FatalException('Invalid response format');

    final cards = <Card>[];
    for (var card in response.body['initialCards']) {
      cards.add(Card.fromJson(card));
    }

    return cards;
  }

  /// throws [ErrorType.state], [ErrorType.validation], [ErrorType.access]
  Future<Card> gameFlowSelectCard(
      String gameId, String triggeredBy, CardType cardType) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    final response = await _put('/api/game/game/selectCard', {
      'gameId': gameId,
      'triggeredBy': triggeredBy,
      'selectCardType': cardType.value()
    });
    if (response.body['gameId'].toString() != gameId ||
        response.body['playerId'].toString() != triggeredBy ||
        response.body['card'] == null ||
        response.body['flowState'].toString() != 'storyTell')
      throw FatalException('Invalid response format');

    final card = Card.fromJson(response.body['card']);

    return card;
  }

  /// throws [ErrorType.state], [ErrorType.validation], [ErrorType.access]
  Future<String> gameFlowNextTurn(String gameId, String triggeredBy) async {
    gameId = _addPrefix(gameId);
    triggeredBy = _addPrefix(triggeredBy);
    final response = await _put(
        '/api/game/game/next', {'gameId': gameId, 'triggeredBy': triggeredBy});
    if (response.body['gameId'].toString() != gameId ||
        response.body['playerId'] == null ||
        response.body['flowState'].toString() != 'selectCard')
      throw FatalException('Invalid response format');

    return response.body['playerId'].toString();
  }
}

class KickResult {
  KickResult(this.success,
      {this.gameStopped = false,
      this.newMasterId,
      this.newAdminId,
      this.nextTurnByUserId});

  final bool success;
  final bool gameStopped;
  final String? newMasterId;
  final String? newAdminId;
  final String? nextTurnByUserId;
}

extension ToJson on Map {
  String toJson() => jsonEncode(this);
}
