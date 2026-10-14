import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/news_remote_data_source.dart';
import '../../data/repositories/news_repository_impl.dart';
import '../../domain/repositories/news_repository.dart';
import '../../domain/usecases/get_top_headlines.dart';
import '../../domain/usecases/search_news.dart';

/// Riverpod provider for [NewsRemoteDataSource].
/// Reuses the centralized [dioClientProvider].
final newsRemoteDataSourceProvider = Provider<NewsRemoteDataSource>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return NewsRemoteDataSourceImpl(dioClient: dioClient);
});

/// Riverpod provider for [NewsRepository].
/// Injects [newsRemoteDataSourceProvider] and [networkInfoProvider].
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final remoteDataSource = ref.watch(newsRemoteDataSourceProvider);
  final networkInfo = ref.watch(networkInfoProvider);
  return NewsRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

/// Riverpod provider for [GetTopHeadlines] use case.
final getTopHeadlinesUseCaseProvider = Provider<GetTopHeadlines>((ref) {
  final repository = ref.watch(newsRepositoryProvider);
  return GetTopHeadlines(repository);
});

/// Riverpod provider for [SearchNews] use case.
final searchNewsUseCaseProvider = Provider<SearchNews>((ref) {
  final repository = ref.watch(newsRepositoryProvider);
  return SearchNews(repository);
});
