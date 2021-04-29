import 'dart:isolate';

import 'package:litgame_client/client.dart';
import 'package:litgame_client/models/card.dart';
import 'package:test/test.dart';

import 'helper.dart';

void serverIsolate(dynamic message) async {
  await createServer();
}

void main() async {
  late GameClient client;
  var receivePort = ReceivePort();
  var isolate;

  setUp(() async {
    if (isolate != null) {
      throw 'shut down the server!';
    }
    isolate = await Isolate.spawn<int>(serverIsolate, 123);
    client = createClient();
  });

  tearDown(() async {
    if (isolate is Isolate) {
      isolate.kill(priority: Isolate.immediate);
      isolate = null;
    }
    receivePort.sendPort.send('die');
    await Future.delayed(Duration(seconds: 1));
  });

  test('version test', () async {
    final version = await client.version;
    expect(version.isNotEmpty, true);
  });

  test('Start game test', () async {
    final gameId = await client.startGame('g-123', 'u-123');
    expect(gameId, prefix + 'g-123');
  });

  test('End game test', () async {
    final gameId = await client.startGame('g-123', 'u-123');
    expect(gameId, prefix + 'g-123');
    var strError = '';
    try {
      await client.endGame(gameId, 'u-456');
    } catch (error) {
      strError = error.toString();
    }
    expect(strError, 'Rest error: {error: Only admin can finish the game!}');

    final success = await client.endGame(gameId, 'u-123');
    expect(success, true);
  });

  test('Join game', () async {
    final gameId = await client.startGame('g-123', 'u-1');
    var success = await client.join(gameId, 'u-2');
    expect(success, true);
    success = await client.join(gameId, 'u-3');
    expect(success, true);
  });

  test('Kick from game', () async {
    final gameId = await client.startGame('g-123', 'u-1');
    var success = await client.join(gameId, 'u-2');
    expect(success, true);
    var result;
    var strError = '';
    try {
      result = await client.kick(gameId, 'u-4', 'u-2');
    } catch (error) {
      strError = error.toString();
    }
    expect(strError, 'Rest error: {error: Only admin can kick users}');
    result = await client.kick(gameId, 'u-2', 'u-2');
    expect(result.success, true);
    expect(result.gameStopped, false);
    result = await client.kick(gameId, 'u-1', 'u-1');
    expect(result.success, true);
    expect(result.gameStopped, true);
  });

  test('Set game master', () async {
    final gameId = await client.startGame('g-123', 'u-1');
    await client.join(gameId, 'u-2');
    await client.join(gameId, 'u-3');

    var strError = '';
    try {
      await client.setMaster(gameId, 'u-2', 'u-3');
    } catch (error) {
      strError = error.toString();
    }
    expect(strError,
        'Rest error: {error: Only admin or another master can set game master}');

    final success = await client.setMaster(gameId, 'u-1', 'u-3');
    expect(success, true);
  });

  test('Finish join', () async {
    final gameId = await client.startGame('g-123', 'u-1');
    await client.join(gameId, 'u-2');
    await client.join(gameId, 'u-3');

    var strError = '';
    try {
      await client.finishJoin(gameId, 'u-3');
    } catch (error) {
      strError = error.toString();
    }
    expect(strError, 'Rest error: {error: Only admin can end join phase}');

    final success = await client.finishJoin(gameId, 'u-1');
    expect(success, true);
  });

  test('Sort players', () async {
    final gameId = await client.startGame('g-123', 'u-1');
    await client.join(gameId, 'u-2');
    await client.join(gameId, 'u-3');
    await client.join(gameId, 'u-4');
    await client.finishJoin(gameId, 'u-1');
    await client.setMaster(gameId, 'u-1', 'u-3');

    var strError = '';
    try {
      await client.sortPlayer(gameId, 'u-2', 'u-1', 0);
    } catch (error) {
      strError = error.toString();
    }
    expect(
        strError, 'Rest error: {error: Only admin or master can sort players}');
    var positions = <int>[];
    positions.add(await client.sortPlayer(gameId, 'u-1', 'u-1', 0));
    positions.add(await client.sortPlayer(gameId, 'u-1', 'u-2', 0));
    positions.add(await client.sortPlayer(gameId, 'u-1', 'u-3', 0));
    positions.add(await client.sortPlayer(gameId, 'u-1', 'u-4', 0));
    expect(positions, [0, 0, 0, 0]);

    strError = '';
    try {
      await client.sortReset(gameId, 'u-4');
    } catch (error) {
      strError = error.toString();
    }
    expect(
        strError, 'Rest error: {error: Only admin or master can sort players}');
    var success = await client.sortReset(gameId, 'u-1');
    expect(success, true);

    positions.clear();
    positions.add(await client.sortPlayer(gameId, 'u-1', 'u-1', 99));
    positions.add(await client.sortPlayer(gameId, 'u-1', 'u-2', 99));
    positions.add(await client.sortPlayer(gameId, 'u-1', 'u-3', 99));
    positions.add(await client.sortPlayer(gameId, 'u-1', 'u-4', 99));
    expect(positions, [0, 1, 2, 3]);
  });

  test('Start training, training step', () async {
    final gameId = await client.startGame('g-123', 'u-1');
    await client.join(gameId, 'u-2');
    await client.join(gameId, 'u-3');
    await client.join(gameId, 'u-4');
    await client.finishJoin(gameId, 'u-1');
    await client.setMaster(gameId, 'u-1', 'u-3');
    await client.sortPlayer(gameId, 'u-1', 'u-1', 99);
    await client.sortPlayer(gameId, 'u-1', 'u-2', 99);
    await client.sortPlayer(gameId, 'u-1', 'u-3', 99);
    await client.sortPlayer(gameId, 'u-1', 'u-4', 99);

    var strError = '';
    try {
      await client.startTrainingFlow(gameId, 'u-4');
    } catch (error) {
      strError = error.toString();
    }
    expect(strError,
        'Rest error: {error: Only admin or master can start training}');

    var success = await client.startTrainingFlow(gameId, 'u-3');
    expect(success, true);

    strError = '';
    try {
      await client.trainingFlowNextTurn(gameId, 'u-4');
    } catch (error) {
      strError = error.toString();
    }
    expect(strError,
        'Rest error: {error: It\'s not user\'s test-u-4 turn now. Player test-u-1 should trigger next turn}');

    var cards = await client.trainingFlowNextTurn(gameId, 'u-1');
    expect(cards.keys.first, 'test-u-2');
    cards = await client.trainingFlowNextTurn(gameId, 'u-2');
    expect(cards.keys.first, 'test-u-3');
  });

  test('Start game,full game flow', () async {
    final gameId = await client.startGame('g-123', 'u-1');
    await client.join(gameId, 'u-2');
    await client.join(gameId, 'u-3');
    await client.join(gameId, 'u-4');
    await client.finishJoin(gameId, 'u-1');
    await client.setMaster(gameId, 'u-1', 'u-3');
    await client.sortPlayer(gameId, 'u-1', 'u-1', 99);
    await client.sortPlayer(gameId, 'u-1', 'u-2', 99);
    await client.sortPlayer(gameId, 'u-1', 'u-3', 99);
    await client.sortPlayer(gameId, 'u-1', 'u-4', 99);

    var strError = '';
    try {
      await client.startGameFlow(gameId, 'u-1');
    } catch (error) {
      strError = error.toString();
    }
    expect(strError,
        'Rest error: {error: Cant start game at state GameState.sorting}');

    await client.startTrainingFlow(gameId, 'u-1');

    var cards = await client.startGameFlow(gameId, 'u-1');
    expect(cards.length, 3);
    final cardTypes = <CardType>[];
    for (var card in cards) {
      cardTypes.add(card.cardType);
    }
    expect(cardTypes, [CardType.generic, CardType.place, CardType.person]);

    var nextPlayer = await client.gameFlowNextTurn(gameId, 'u-1');
    expect(nextPlayer, 'test-u-2');
    var card =
        await client.gameFlowSelectCard(gameId, nextPlayer, CardType.person);
    expect(card.cardType, CardType.person);
    nextPlayer = await client.gameFlowNextTurn(gameId, nextPlayer);
    expect(nextPlayer, 'test-u-3');
  });
}
