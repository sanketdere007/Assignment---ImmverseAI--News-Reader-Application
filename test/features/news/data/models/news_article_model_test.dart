import 'package:flutter_test/flutter_test.dart';
import 'package:quicknews/features/news/data/models/news_article_model.dart';
import 'package:quicknews/features/news/data/models/news_response_model.dart';
import 'package:quicknews/features/news/data/models/news_source_model.dart';
import 'package:quicknews/features/news/domain/entities/news_article.dart';

void main() {
  group('NewsArticleModel and NewsResponseModel JSON Parsing', () {
    final tCompleteArticleJson = <String, dynamic>{
      'source': {
        'id': 'techcrunch',
        'name': 'TechCrunch',
      },
      'author': 'Jane Doe',
      'title': 'AI Breakthrough in Flutter Development',
      'description': 'A new development pattern was unveiled today.',
      'url': 'https://techcrunch.com/article-1',
      'urlToImage': 'https://techcrunch.com/images/1.png',
      'publishedAt': '2026-10-14T08:00:00Z',
      'content': 'Full article preview content here...',
    };

    final tMinimalArticleJson = <String, dynamic>{
      'source': null,
      'author': null,
      'title': null,
      'description': null,
      'url': null,
      'urlToImage': null,
      'publishedAt': null,
      'content': null,
    };

    final tMalformedDateJson = <String, dynamic>{
      'source': {'id': null, 'name': null},
      'author': 'Test Author',
      'title': 'Valid Title',
      'description': 'Valid Description',
      'url': 'https://example.com/test',
      'urlToImage': 'invalid-image-url',
      'publishedAt': 'not-a-valid-date-string',
      'content': 'Content',
    };

    test('should parse complete JSON successfully into NewsArticleModel', () {
      final model = NewsArticleModel.fromJson(tCompleteArticleJson);

      expect(model.source?.id, 'techcrunch');
      expect(model.source?.name, 'TechCrunch');
      expect(model.author, 'Jane Doe');
      expect(model.title, 'AI Breakthrough in Flutter Development');
      expect(model.description, 'A new development pattern was unveiled today.');
      expect(model.url, 'https://techcrunch.com/article-1');
      expect(model.urlToImage, 'https://techcrunch.com/images/1.png');
      expect(model.publishedAt, DateTime.parse('2026-10-14T08:00:00Z'));
      expect(model.content, 'Full article preview content here...');
    });

    test('should handle missing optional fields safely without throwing', () {
      final model = NewsArticleModel.fromJson(tMinimalArticleJson);

      expect(model.source, isNull);
      expect(model.author, isNull);
      expect(model.title, isNull);
      expect(model.description, isNull);
      expect(model.url, isNull);
      expect(model.urlToImage, isNull);
      expect(model.publishedAt, isNull);
      expect(model.content, isNull);

      // Verify domain mapping handles nulls safely
      final entity = model.toEntity();
      expect(entity.title, 'Untitled Article');
      expect(entity.url, '');
      expect(entity.sourceName, 'Unknown Source');
      expect(entity.hasValidImage, isFalse);
    });

    test('should handle malformed publication date string safely as null', () {
      final model = NewsArticleModel.fromJson(tMalformedDateJson);

      expect(model.publishedAt, isNull);
      expect(model.title, 'Valid Title');

      final entity = model.toEntity();
      expect(entity.publishedAt, isNull);
      expect(entity.sourceName, 'Unknown Source');
      expect(entity.hasValidImage, isFalse);
    });

    test('should serialize and deserialize model maintaining value equality', () {
      final model = NewsArticleModel.fromJson(tCompleteArticleJson);
      final json = model.toJson();
      final reconstructed = NewsArticleModel.fromJson(json);

      expect(reconstructed, equals(model));
      expect(reconstructed.hashCode, equals(model.hashCode));
    });

    test('should correctly map NewsArticleModel to NewsArticle domain entity', () {
      final model = NewsArticleModel.fromJson(tCompleteArticleJson);
      final entity = model.toEntity();

      expect(entity, isA<NewsArticle>());
      expect(entity.title, 'AI Breakthrough in Flutter Development');
      expect(entity.author, 'Jane Doe');
      expect(entity.source?.name, 'TechCrunch');
      expect(entity.sourceName, 'TechCrunch');
      expect(entity.hasValidImage, isTrue);
      expect(entity.uri, Uri.parse('https://techcrunch.com/article-1'));

      // Verify reverse mapping from entity to model
      final reversedModel = NewsArticleModel.fromEntity(entity);
      expect(reversedModel.title, entity.title);
      expect(reversedModel.url, entity.url);
      expect(reversedModel.source?.name, entity.source?.name);
    });

    test('should parse NewsResponseModel with article collection', () {
      final responseJson = <String, dynamic>{
        'status': 'ok',
        'totalResults': 1,
        'articles': [tCompleteArticleJson],
      };

      final responseModel = NewsResponseModel.fromJson(responseJson);

      expect(responseModel.isSuccess, isTrue);
      expect(responseModel.totalResults, 1);
      expect(responseModel.articles?.length, 1);

      final entities = responseModel.toEntities();
      expect(entities.length, 1);
      expect(entities.first.title, 'AI Breakthrough in Flutter Development');
    });

    test('should handle empty or malformed article arrays in NewsResponseModel', () {
      final emptyResponseJson = <String, dynamic>{
        'status': 'ok',
        'totalResults': 0,
        'articles': <dynamic>[],
      };

      final responseModel = NewsResponseModel.fromJson(emptyResponseJson);
      expect(responseModel.isSuccess, isTrue);
      expect(responseModel.totalResults, 0);
      expect(responseModel.toEntities(), isEmpty);

      // Malformed array with null/string elements instead of maps
      final malformedArrayJson = <String, dynamic>{
        'status': 'ok',
        'totalResults': 1,
        'articles': [
          'not a map',
          null,
          123,
          tCompleteArticleJson,
        ],
      };

      final malformedModel = NewsResponseModel.fromJson(malformedArrayJson);
      expect(malformedModel.articles?.length, 1);
      expect(malformedModel.toEntities().length, 1);
    });

    test('should parse NewsSourceModel and handle null/empty names', () {
      const source = NewsSourceModel(id: null, name: '  ');
      final entity = source.toEntity();

      expect(entity.id, isNull);
      expect(entity.name, 'Unknown Source');
    });
  });
}
