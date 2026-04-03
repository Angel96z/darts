Map<String, dynamic> buildCricketRowState(
  List<Map<String, dynamic>> allPlayers,
  Map<String, dynamic> player,
  String target,
) {
  final cricket = Map<String, dynamic>.from(player['cricket'] ?? {});
  final value = (cricket[target] as int?) ?? 0;

  final isOpened = value >= 3;

  final allOpened = allPlayers.every((p) {
    final c = Map<String, dynamic>.from(p['cricket'] ?? {});
    return (c[target] as int? ?? 0) >= 3;
  });

  final isClosed = allOpened;
  final canScore = isOpened && !isClosed;

  final marks = List<String>.generate(
    value.clamp(0, 3),
    (i) => 'X',
  );

  while (marks.length < 3) {
    marks.add('-');
  }

  return {
    'value': value,
    'isClosed': isClosed,
    'canScore': canScore,
    'marksDisplay': marks,
  };
}
