import '../../core/api_client.dart';
import '../models.dart';

class LibraryRepository {
  LibraryRepository(this._api);

  final ApiClient _api;

  Future<List<LibraryCategory>> categories() async {
    final response = await _api.get('/library/categories');
    final list = response['categories'] as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((item) => LibraryCategory.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<LibraryProduct>> products({String? categoryId}) async {
    final response = await _api.get(
      '/library/products',
      query: {
        if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      },
    );
    final list = response['products'] as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((item) => LibraryProduct.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
