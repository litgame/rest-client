enum CardType { generic, person, place }

extension StringType on CardType {
  String value() {
    switch (this) {
      case CardType.generic:
        return 'generic';
      case CardType.person:
        return 'person';
      case CardType.place:
        return 'place';
    }
  }

  CardType getTypeByName(String name) {
    switch (name) {
      case 'generic':
        return CardType.generic;
      case 'person':
        return CardType.person;
      case 'place':
        return CardType.place;
    }
    throw 'No such type: ' + name;
  }
}

class Card {
  Card(this.name, this.imgUrl, this.cardType, this.collectionName);

  Card.fromJson(Map<String, dynamic> json) {
    for (var required in ['name', 'imgUrl', 'cardType', 'collection']) {
      if (json[required] == null) {
        throw 'Invalid json format';
      }
    }
    name = json['name'].toString();
    imgUrl = json['imgUrl'].toString();
    cardType = CardType.generic.getTypeByName(json['cardType'].toString());
    collectionName = json['collectionName'].toString();
  }

  late final String name;
  late final String imgUrl;
  late final CardType cardType;
  late final String collectionName;
}
