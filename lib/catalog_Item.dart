import 'dart:convert'; // ignore: file_names

class CatalogItem {

  String uuid;
  String name;
  List<CatalogItem> children;
  bool isSelected;

  CatalogItem({
    required this.uuid,
    required this.name,
    required this.children,
    this.isSelected = false,
  });

  void setSelected(bool value) {
    isSelected = value;
  }

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
        uuid: json['uuid'],
        name: json['name'],
        children: json["children"] == null
            ? []
            : List<CatalogItem>.from(
                json["children"].map((item) => CatalogItem.fromJson(item))),
        isSelected: json['isSelected'] ?? false);
  }

  Map<String, dynamic> toJson() => {
        "uuid": uuid,
        "name": name,
        "children": children,
        "isSelected": isSelected,
      };
}

List<CatalogItem> catalogItemFromJson(String str) => List<CatalogItem>.from(
    json.decode(str)['config'].map((x) => CatalogItem.fromJson(x)));

String catalogItemToJson(List<CatalogItem> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));
