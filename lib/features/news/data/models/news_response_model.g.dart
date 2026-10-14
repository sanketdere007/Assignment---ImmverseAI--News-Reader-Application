// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NewsResponseModel _$NewsResponseModelFromJson(Map<String, dynamic> json) =>
    NewsResponseModel(
      status: json['status'] as String?,
      totalResults: json['totalResults'] is num
          ? (json['totalResults'] as num).toInt()
          : null,
      articles: (json['articles'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(NewsArticleModel.fromJson)
          .toList(),
      code: json['code'] as String?,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$NewsResponseModelToJson(NewsResponseModel instance) =>
    <String, dynamic>{
      'status': instance.status,
      'totalResults': instance.totalResults,
      'articles': instance.articles?.map((e) => e.toJson()).toList(),
      'code': instance.code,
      'message': instance.message,
    };
