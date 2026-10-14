import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import '../datasources/news_remote_data_source.dart';

/// Implementation of [NewsRepository] coordinating remote data access
/// and mapping data models into Clean Architecture domain entities.
class NewsRepositoryImpl implements NewsRepository {
  final NewsRemoteDataSource _remoteDataSource;
  final NetworkInfo? _networkInfo;

  const NewsRepositoryImpl({
    required NewsRemoteDataSource remoteDataSource,
    NetworkInfo? networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  @override
  Future<List<NewsArticle>> getTopHeadlines({
    String? country,
    String? category,
    String? sources,
    String? query,
    int page = 1,
    int pageSize = ApiConstants.defaultPageSize,
  }) async {
    await _checkConnectivity();

    try {
      final responseModel = await _remoteDataSource.getTopHeadlines(
        country: country,
        category: category,
        sources: sources,
        query: query,
        page: page,
        pageSize: pageSize,
      );

      return responseModel.toPaginatedNews();
    } on AppError {
      rethrow;
    } on DioException catch (e) {
      throw ErrorHandler.fromDioException(e);
    } catch (e, stack) {
      throw ErrorHandler.fromException(e, stack);
    }
  }

  @override
  Future<List<NewsArticle>> searchNews({
    required String query,
    String? domains,
    String? sortBy,
    int page = 1,
    int pageSize = ApiConstants.defaultPageSize,
  }) async {
    await _checkConnectivity();

    try {
      final responseModel = await _remoteDataSource.getEverything(
        query: query,
        domains: domains,
        sortBy: sortBy,
        page: page,
        pageSize: pageSize,
      );

      return responseModel.toPaginatedNews();
    } on AppError {
      rethrow;
    } on DioException catch (e) {
      throw ErrorHandler.fromDioException(e);
    } catch (e, stack) {
      throw ErrorHandler.fromException(e, stack);
    }
  }

  Future<void> _checkConnectivity() async {
    if (_networkInfo != null) {
      final isConnected = await _networkInfo.isConnected;
      if (!isConnected) {
        throw const NetworkError(
          'No internet connection. Please check your network and try again.',
          'NO_INTERNET',
        );
      }
    }
  }
}
