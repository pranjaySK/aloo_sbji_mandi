import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aloo_sbji_mandi/core/constants/api_constant.dart';

class PostService {
  static String get baseUrl => '${ApiConstants.baseUrl}/api/v1';

  dynamic _safeDecodeBody(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get all posts
  Future<Map<String, dynamic>> getAllPosts({String? category, int limit = 20, int page = 1}) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'page': page.toString(),
      };
      if (category != null) queryParams['category'] = category;

      final uri = Uri.parse('$baseUrl/posts')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch posts'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create post
  Future<Map<String, dynamic>> createPost({
    required String content,
    String? category,
    List<String>? images,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/posts/create'),
        headers: headers,
        body: json.encode({
          'content': content,
          'category': category ?? 'general',
          'images': images ?? [],
        }),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to create post'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update post
  Future<Map<String, dynamic>> updatePost(
    String postId, {
    required String content,
    String? category,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'content': content,
      };
      if (category != null) body['category'] = category;

      final encodedBody = json.encode(body);
      final urls = [
        '$baseUrl/posts/$postId',
        '$baseUrl/posts/update/$postId',
      ];

      String? lastErrorMessage;

      for (final url in urls) {
        final patchResponse = await http.patch(
          Uri.parse(url),
          headers: headers,
          body: encodedBody,
        );
        final patchData = _safeDecodeBody(patchResponse.body);
        if (patchResponse.statusCode == 200 && patchData is Map<String, dynamic>) {
          return {
            'success': true,
            'data': patchData['data'],
            'message': patchData['message'],
          };
        }
        if (patchData is Map<String, dynamic>) {
          lastErrorMessage = patchData['message']?.toString();
        }

        final postResponse = await http.post(
          Uri.parse(url),
          headers: headers,
          body: encodedBody,
        );
        final postData = _safeDecodeBody(postResponse.body);
        if (postResponse.statusCode == 200 && postData is Map<String, dynamic>) {
          return {
            'success': true,
            'data': postData['data'],
            'message': postData['message'],
          };
        }
        if (postData is Map<String, dynamic>) {
          lastErrorMessage = postData['message']?.toString() ?? lastErrorMessage;
        }

        final putResponse = await http.put(
          Uri.parse(url),
          headers: headers,
          body: encodedBody,
        );
        final putData = _safeDecodeBody(putResponse.body);
        if (putResponse.statusCode == 200 && putData is Map<String, dynamic>) {
          return {
            'success': true,
            'data': putData['data'],
            'message': putData['message'],
          };
        }
        if (putData is Map<String, dynamic>) {
          lastErrorMessage = putData['message']?.toString() ?? lastErrorMessage;
        }
      }

      return {
        'success': false,
        'message':
            lastErrorMessage ??
            'Failed to update post. Please try again after backend update.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete post
  Future<Map<String, dynamic>> deletePost(String postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to delete post'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Like/Unlike post
  Future<Map<String, dynamic>> toggleLike(String postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Add comment
  Future<Map<String, dynamic>> addComment(String postId, String text) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comment'),
        headers: headers,
        body: json.encode({'text': text}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Reply to comment
  Future<Map<String, dynamic>> replyToComment(String postId, String commentId, String text) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comment/$commentId/reply'),
        headers: headers,
        body: json.encode({'text': text}),
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to add reply'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Like/Unlike comment
  Future<Map<String, dynamic>> toggleCommentLike(String postId, String commentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/posts/$postId/comment/$commentId/like'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data'], 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to like comment'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Track share
  Future<Map<String, dynamic>> trackShare(String postId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/posts/$postId/share'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to track share'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete comment
  Future<Map<String, dynamic>> deleteComment(String postId, String commentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId/comment/$commentId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to delete comment'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update comment
  Future<Map<String, dynamic>> updateComment(String postId, String commentId, String text) async {
    try {
      final headers = await _getHeaders();
      
      // Try PATCH first, then POST as fallback
      for (final method in ['PATCH', 'POST', 'PUT']) {
        for (final url in [
          '$baseUrl/posts/$postId/comment/$commentId',
          '$baseUrl/posts/$postId/comment/$commentId/update',
        ]) {
          try {
            late http.Response response;
            if (method == 'PATCH') {
              response = await http.patch(
                Uri.parse(url),
                headers: headers,
                body: json.encode({'text': text}),
              );
            } else if (method == 'PUT') {
              response = await http.put(
                Uri.parse(url),
                headers: headers,
                body: json.encode({'text': text}),
              );
            } else {
              response = await http.post(
                Uri.parse(url),
                headers: headers,
                body: json.encode({'text': text}),
              );
            }

            final bodyStr = response.body;
            final data = _safeDecodeBody(bodyStr);
            
            if (response.statusCode == 200 && data != null) {
              return {'success': true};
            } else if (data != null && data['message'] != null) {
              return {'success': false, 'message': data['message']};
            }
          } catch (_) {
            continue;
          }
        }
      }
      return {'success': false, 'message': 'Failed to update comment'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete reply
  Future<Map<String, dynamic>> deleteReply(String postId, String commentId, String replyId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId/comment/$commentId/reply/$replyId'),
        headers: headers,
      );
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to delete reply'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update reply
  Future<Map<String, dynamic>> updateReply(String postId, String commentId, String replyId, String text) async {
    try {
      final headers = await _getHeaders();
      
      // Try PATCH first, then POST as fallback
      for (final method in ['PATCH', 'POST', 'PUT']) {
        for (final url in [
          '$baseUrl/posts/$postId/comment/$commentId/reply/$replyId',
          '$baseUrl/posts/$postId/comment/$commentId/reply/$replyId/update',
        ]) {
          try {
            late http.Response response;
            if (method == 'PATCH') {
              response = await http.patch(
                Uri.parse(url),
                headers: headers,
                body: json.encode({'text': text}),
              );
            } else if (method == 'PUT') {
              response = await http.put(
                Uri.parse(url),
                headers: headers,
                body: json.encode({'text': text}),
              );
            } else {
              response = await http.post(
                Uri.parse(url),
                headers: headers,
                body: json.encode({'text': text}),
              );
            }

            final bodyStr = response.body;
            final data = _safeDecodeBody(bodyStr);
            
            if (response.statusCode == 200 && data != null) {
              return {'success': true};
            } else if (data != null && data['message'] != null) {
              return {'success': false, 'message': data['message']};
            }
          } catch (_) {
            continue;
          }
        }
      }
      return {'success': false, 'message': 'Failed to update reply'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get single post
  Future<Map<String, dynamic>> getPost(String postId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/posts/$postId'));
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to fetch post'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Check if current user liked a post
  Future<bool> isPostLikedByUser(List<dynamic> likes) async {
    final userId = await getCurrentUserId();
    if (userId == null) return false;
    return likes.any((like) => 
      (like is String ? like : like['_id']?.toString()) == userId
    );
  }

  // Check if current user liked a comment
  Future<bool> isCommentLikedByUser(List<dynamic> likes) async {
    final userId = await getCurrentUserId();
    if (userId == null) return false;
    return likes.any((like) => 
      (like is String ? like : like['_id']?.toString()) == userId
    );
  }
}
