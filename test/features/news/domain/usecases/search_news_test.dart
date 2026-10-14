import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';
import 'package:quicknews/features/news/domain/entities/news_source.dart';
import 'package:quicknews/features/news/domain/repositories/news_repository.dart';
import 'package:quicknews/features/news/domain/usecases/search_news.dart';

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
  late SearchNews useCase;

  setUp(() {
    fakeRepository = FakeNewsRepository();
    useCase = SearchNews(fakeRepository);
  });

  group('SearchNews UseCase', () {
    const tArticle = NewsArticle(
      source: NewsSource(name: 'Wall Street Journal'),
      title: 'Economy and Tech Insights',
      url: 'https://wsj.com/article/1',
    );

    test('should forward search parameters to repository', () async {
      fakeRepository.articlesToReturn = [tArticle];

      final result = await useCase(
        query: 'electric vehicles',
        domains: 'wsj.com',
        sortBy: 'publishedAt',
        page: 2,
        pageSize: 20,
      );

      expect(result, [tArticle]);
      expect(fakeRepository.lastCallParameters, {
        'query': 'electric vehicles',
        'domains': 'wsj.com',
        'sortBy': 'publishedAt',
        'page': 2,
        'pageSize': 20,
      });
    });
  });
}
