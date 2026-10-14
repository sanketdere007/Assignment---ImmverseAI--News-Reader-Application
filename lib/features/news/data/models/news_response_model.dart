import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/news_article.dart';
import 'news_article_model.dart';

part 'news_response_model.g.dart';

/// Top-level response model returned by News API endpoints.
@JsonSerializable(explicitToJson: true)
@immutable
class NewsResponseModel {
  /// Status of the response: 'ok' or 'error'.
  final String? status;

  /// Total count of matching articles returned by the provider.
  final int? totalResults;

  /// List of article models parsed from the response.
  final List<NewsArticleModel>? articles;

  /// Provider error code (e.g. 'apiKeyMissing', 'rateLimited', 'apiKeyInvalid').
  final String? code;

  /// Human-readable explanation of error if [status] == 'error'.
  final String? message;

  const NewsResponseModel({
    this.status,
    this.totalResults,
    this.articles,
    this.code,
    this.message,
  });

  /// Factory constructor to parse JSON into [NewsResponseModel].
  factory NewsResponseModel.fromJson(Map<String, dynamic> json) =>
      _$NewsResponseModelFromJson(json);

  /// Converts this model into a JSON map.
  Map<String, dynamic> toJson() => _$NewsResponseModelToJson(this);

  /// Indicates if the API reported a successful operation.
  bool get isSuccess => status?.toLowerCase() == 'ok';

  /// Converts inner article models to domain [NewsArticle] entities.
  List<NewsArticle> toEntities() {
    return articles?.map((article) => article.toEntity()).toList() ??
        const <NewsArticle>[];
  }

  NewsResponseModel copyWith({
    String? status,
    int? totalResults,
    List<NewsArticleModel>? articles,
    String? code,
    String? message,
  }) {
    return NewsResponseModel(
      status: status ?? this.status,
      totalResults: totalResults ?? this.totalResults,
      articles: articles ?? this.articles,
      code: code ?? this.code,
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsResponseModel &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          totalResults == other.totalResults &&
          listEquals(articles, other.articles) &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(
        status,
        totalResults,
        articles == null ? 0 : Object.hashAll(articles!),
        code,
        message,
      );

  @override
  String toString() =>
      'NewsResponseModel(status: $status, totalResults: $totalResults, articlesCount: ${articles?.length})';
}
