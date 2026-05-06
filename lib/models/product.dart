class Product {
  final String id;
  final String name;
  final String? genre;
  final String? imageUrl;
  final double? contentVolume;
  final String? contentUnit;
  final int daysToConsume;
  final String nextDueDate;
  final int daysRemaining;
  final String status;

  const Product({
    required this.id,
    required this.name,
    this.genre,
    this.imageUrl,
    this.contentVolume,
    this.contentUnit,
    required this.daysToConsume,
    required this.nextDueDate,
    required this.daysRemaining,
    required this.status,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        genre: json['genre'] as String?,
        imageUrl: json['image_url'] as String?,
        contentVolume: (json['content_volume'] as num?)?.toDouble(),
        contentUnit: json['content_unit'] as String?,
        daysToConsume: json['days_to_consume'] as int,
        nextDueDate: json['next_due_date'] as String,
        daysRemaining: json['days_remaining'] as int,
        status: json['status'] as String,
      );
}

class SearchItem {
  final String itemCode;
  final String name;
  final String genre;
  final String imageUrl;
  final double contentVolume;
  final String contentUnit;

  const SearchItem({
    required this.itemCode,
    required this.name,
    required this.genre,
    required this.imageUrl,
    required this.contentVolume,
    required this.contentUnit,
  });

  factory SearchItem.fromJson(Map<String, dynamic> json) => SearchItem(
        itemCode: json['item_code'] as String? ?? '',
        name: json['name'] as String,
        genre: json['genre'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        contentVolume: (json['content_volume'] as num?)?.toDouble() ?? 0,
        contentUnit: json['content_unit'] as String? ?? '',
      );
}

class CalendarItem {
  final String productId;
  final String name;
  final String? genre;
  final String? imageUrl;
  final String status;

  const CalendarItem({
    required this.productId,
    required this.name,
    this.genre,
    this.imageUrl,
    required this.status,
  });

  factory CalendarItem.fromJson(Map<String, dynamic> json) => CalendarItem(
        productId: json['product_id'] as String,
        name: json['name'] as String,
        genre: json['genre'] as String?,
        imageUrl: json['image_url'] as String?,
        status: json['status'] as String,
      );
}

class CalendarDate {
  final DateTime date;
  final List<CalendarItem> items;

  const CalendarDate({required this.date, required this.items});

  factory CalendarDate.fromJson(Map<String, dynamic> json) => CalendarDate(
        date: DateTime.parse(json['date'] as String),
        items: (json['items'] as List<dynamic>)
            .map((e) => CalendarItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
