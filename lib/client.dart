import 'dart:convert';

import 'package:litgame_client/models/card_collection.dart';
import 'package:rest_client/rest_client.dart';

import 'models/card.dart';

class GameClient {
  GameClient(this._baseUrl, [this._idPrefix = '']) : _client = Client();
  String _baseUrl;
  String _idPrefix;
  final Client _client;

  Future<Response> _get(String url) async {
    final request = Request(url: _baseUrl + '$url');
    final response = await _client.execute(request: request);

    if (response.statusCode != 200)
      throw 'Rest error: ' + response.body.toString();

    return response;
  }

  Future<Response> _put(String url, Map<String, dynamic> body) async {
    final request = Request(
        url: _baseUrl + '$url', method: RequestMethod.put, body: body.toJson());

    try {
      return await _client.execute(request: request);
    } on RestException catch (error) {
      throw 'Rest error: ' + error.response.body.toString();
    }
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

  Future<String> startGame(String gameId, String adminId) async {
    final response = await _put('/api/game/start',
        {'gameId': _idPrefix + gameId, 'adminId': _idPrefix + adminId});

    if (response.body['gameId'] == null) throw 'Invalid response format';
    if (response.body['status'].toString() != 'started')
      throw 'Invalid game state';
    return response.body['gameId'].toString();
  }

  Future<bool> endGame(String gameId, String triggeredBy) async {
    final response = await _put('/api/game/end',
        {'gameId': _idPrefix + gameId, 'triggeredBy': _idPrefix + triggeredBy});
    if (response.body['gameId'] == null) throw 'Invalid response format';
    if (response.body['status'].toString() != 'finished') return false;
    return true;
  }

  Future<bool> join(String gameId, String triggeredBy) async {
    final response = await _put('/api/game/join',
        {'gameId': _idPrefix + gameId, 'triggeredBy': _idPrefix + triggeredBy});
    if (response.body['userId'].toString() != triggeredBy)
      throw 'Invalid response format';
    if (response.body['joined'].toString() != 'true') return false;
    return true;
  }

  Future<KickResult> kick(
      String gameId, String triggeredBy, String targetUserId) async {
    final response = await _put('/api/game/kick', {
      'gameId': _idPrefix + gameId,
      'triggeredBy': _idPrefix + triggeredBy,
      'targetUserId': _idPrefix + targetUserId
    });

    if (response.body['gameId'].toString() == gameId &&
        response.body['status'].toString() == 'finished') {
      return KickResult(true, gameStopped: true);
    }

    if (response.body['userId'] == null) throw 'Invalid response format';
    final kicked = response.body['userId'].toString();
    if (kicked != targetUserId) throw 'Another user was kicked: $kicked';

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

  Future<bool> finishJoin(String gameId, String triggeredBy) async {
    final response = await _put('/api/game/finishJoin',
        {'gameId': _idPrefix + gameId, 'triggeredBy': _idPrefix + triggeredBy});
    if (response.body['gameId'].toString() != _idPrefix + gameId)
      throw 'Invalid response format';

    if (response.body['state'].toString() != 'sorting') return false;

    return true;
  }

  Future<bool> setMaster(
      String gameId, String triggeredBy, String targetUserId) async {
    final response = await _put('/api/game/setMaster', {
      'gameId': _idPrefix + gameId,
      'triggeredBy': _idPrefix + triggeredBy,
      'targetUserId': _idPrefix + targetUserId
    });
    if (response.body['gameId'].toString() != _idPrefix + gameId)
      throw 'Invalid response format';

    if (response.body['newMaster'].toString() != _idPrefix + targetUserId)
      return false;

    return true;
  }

  Future<int> sortPlayer(String gameId, String triggeredBy, String targetUserId,
      int position) async {
    final response = await _put('/api/game/sortPlayer', {
      'gameId': _idPrefix + gameId,
      'triggeredBy': _idPrefix + triggeredBy,
      'targetUserId': _idPrefix + targetUserId,
      'position': position
    });
    if (response.body['gameId'].toString() != _idPrefix + gameId ||
        response.body['playerPosition'] == null)
      throw 'Invalid response format';

    return int.parse(response.body['playerPosition'].toString());
  }

  Future<bool> sortReset(String gameId, String triggeredBy) async {
    final response = await _put('/api/game/sortReset',
        {'gameId': _idPrefix + gameId, 'triggeredBy': _idPrefix + triggeredBy});
    if (response.body['gameId'].toString() != _idPrefix + gameId)
      throw 'Invalid response format';

    return true;
  }

  Future<bool> startTrainingFlow(String gameId, String triggeredBy) async {
    final response = await _put('/api/game/training/start',
        {'gameId': _idPrefix + gameId, 'triggeredBy': _idPrefix + triggeredBy});
    if (response.body['gameId'].toString() != _idPrefix + gameId)
      throw 'Invalid response format';

    if (response.body['state'].toString() != 'training') return false;

    return true;
  }

  Future<Map<String, Card>> trainingFlowNextTurn(
      String gameId, String triggeredBy) async {
    final response = await _put('/api/game/training/next',
        {'gameId': _idPrefix + gameId, 'triggeredBy': _idPrefix + triggeredBy});
    if (response.body['gameId'].toString() != _idPrefix + gameId ||
        response.body['card'] == null ||
        response.body['playerId'] == null) throw 'Invalid response format';

    final card = Card.fromJson(response.body['card']);

    return {response.body['playerId'].toString(): card};
  }

  Future<List<Card>> startGameFlow(String gameId, String triggeredBy) async {
    final response = await _put('/api/game/game/start',
        {'gameId': _idPrefix + gameId, 'triggeredBy': _idPrefix + triggeredBy});
    if (response.body['gameId'].toString() != _idPrefix + gameId ||
        response.body['state'].toString() != 'game' ||
        response.body['flowState'].toString() != 'storyTell')
      throw 'Invalid response format';

    if (response.body['initialCards'] == null) throw 'Invalid response format';

    final cards = <Card>[];
    for (var card in response.body['initialCards']) {
      cards.add(Card.fromJson(card));
    }

    return cards;
  }

  Future<Card> gameFlowSelectCard(
      String gameId, String triggeredBy, CardType cardType) async {
    final response = await _put('/api/game/game/selectCard', {
      'gameId': _idPrefix + gameId,
      'triggeredBy': _idPrefix + triggeredBy,
      'selectCardType': cardType.value()
    });
    if (response.body['gameId'].toString() != _idPrefix + gameId ||
        response.body['playerId'].toString() != _idPrefix + triggeredBy ||
        response.body['card'] == null ||
        response.body['flowState'].toString() != 'storyTell')
      throw 'Invalid response format';

    final card = Card.fromJson(response.body['card']);

    return card;
  }

  Future<String> gameFlowNextTurn(String gameId, String triggeredBy) async {
    final response = await _put('/api/game/game/next',
        {'gameId': _idPrefix + gameId, 'triggeredBy': _idPrefix + triggeredBy});
    if (response.body['gameId'].toString() != _idPrefix + gameId ||
        response.body['playerId'] == null ||
        response.body['flowState'].toString() != 'selectCard')
      throw 'Invalid response format';

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
