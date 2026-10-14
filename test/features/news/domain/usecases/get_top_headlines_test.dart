import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';
import 'package:quicknews/features/news/domain/repositories/news_repository.dart';
import 'package:quicknews/features/news/domain/usecases/get_top_headlines.dart';

class FakeNewsRepository implements NewsRepository {
  List<NewsArticle> articlesToReturn = const [];
  Map<String, dynamic>? lastCallParameters;

  @override
  Future<List<NewsArticle>> getTopHeadlines({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    lastCallParameters = {
      'country': country,
      'category': category,
      'sources': sources,
      'query': query,
      'page': page,
      'pageSize': pageSize,
    };
    return articlesToReturn;
  }

  @override
  Future<List<NewsArticle>> searchNews({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = 20,
  }) async {
    lastCallParameters = {
      'query': query,
      'domains': domains,
      'sortBy': sortBy,
      'page': page,
      'pageSize': pageSize,
    };
    return articlesToReturn;
  }
}

void main() {
  late FakeNewsRepository fakeRepository;
  late GetTopHeadlines useCase;

  setUp(() {
    fakeRepository = FakeNewsRepository();
    useCase = GetTopHeadlines(fakeRepository);
  });

  group('GetTopHeadlines UseCase', () {
    const tArticle = NewsArticle(
      source: NewsSource(name: 'Reuters'),
      title: 'Global Markets Update',
      url: 'https://reuters.com/markets/1',
    );

    test('should forward request to repository and return articles', () async {
      fakeRepository.articlesToReturn = [tArticle];

      final result = await useCase(
        country: 'us',
        category: 'business',
        sources: 'techcrunch',
        query: 'inflation',
        page: 3,
        pageSize: 10,
      );

      expect(result, [tArticle]);
      expect(fakeRepository.lastCallParameters, {
        'country': 'us',
        'category': 'business',
        'sources': 'techcrunch',
        'query': 'inflation',
        'page': 3,
        'pageSize': 10,
      });
    });
  });
}
