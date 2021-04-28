class CardCollection {
  CardCollection([this.name = 'default']);

  factory CardCollection.fromJson(Map<String, dynamic> json) {
    final collection = CardCollection(json['name']);
    collection.objectId = json['objectId'];
    return collection;
  }

  final String name;
  String? objectId;
}
