import 'dart:convert';

import 'package:http/http.dart' as http;

class Channel {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final List<String> members;
  final DateTime createdAt;

  Channel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.members,
    required this.createdAt,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      createdBy: json['createdBy'] ?? '',
      members: List<String>.from(json['members'] ?? []),
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class ChannelMessage {
  final String id;
  final String channelId;
  final String senderId;
  final String content;
  final DateTime timestamp;

  ChannelMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.content,
    required this.timestamp,
  });

  factory ChannelMessage.fromJson(Map<String, dynamic> json) {
    return ChannelMessage(
      id: json['_id'] ?? '',
      channelId: json['channelId'] ?? '',
      senderId: json['senderId'] ?? '',
      content: json['content'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class ChannelService {
  final String baseUrl = 'https://farmcare-backend-new.onrender.com/api/v1';

  Future<List<Channel>> getAllChannels(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/channel/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Get channels response status: ${response.statusCode}');
      print('Get channels response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          if (responseData['data'] is Map) {
            // Handle the case where data is a map with 'joined' and 'notJoined' lists
            final Map<String, dynamic> data = responseData['data'];
            final List<Channel> allChannels = [];

            if (data['joined'] != null) {
              allChannels.addAll((data['joined'] as List)
                  .map((json) => Channel.fromJson(json)));
            }

            if (data['notJoined'] != null) {
              allChannels.addAll((data['notJoined'] as List)
                  .map((json) => Channel.fromJson(json)));
            }

            return allChannels;
          } else if (responseData['data'] is List) {
            // Handle the case where data is a direct list of channels
            final List<dynamic> data = responseData['data'];
            return data.map((json) => Channel.fromJson(json)).toList();
          }
        }
      }

      throw Exception('Failed to load channels');
    } catch (e) {
      print('Error getting channels: $e');
      throw Exception('Failed to load channels: $e');
    }
  }

  Future<List<ChannelMessage>> getChannelMessages(
      String channelId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/channel/messages/$channelId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Get channel messages response status: ${response.statusCode}');
      print('Get channel messages response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> messages = responseData['data'];
          return messages.map((json) => ChannelMessage.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to load channel messages');
    } catch (e) {
      print('Error getting channel messages: $e');
      throw Exception('Failed to load channel messages: $e');
    }
  }

  Future<void> joinChannel(String channelId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channel/join/$channelId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Join channel response status: ${response.statusCode}');
      print('Join channel response body: ${response.body}');

      if (response.statusCode != 200) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to join channel');
      }
    } catch (e) {
      print('Error joining channel: $e');
      throw Exception('Failed to join channel: $e');
    }
  }

  Future<void> leaveChannel(String channelId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channel/leave/$channelId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Leave channel response status: ${response.statusCode}');
      print('Leave channel response body: ${response.body}');

      if (response.statusCode != 200) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to leave channel');
      }
    } catch (e) {
      print('Error leaving channel: $e');
      throw Exception('Failed to leave channel: $e');
    }
  }

  Future<Channel> createChannel(
      String name, String description, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channel/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': name,
          'description': description,
        }),
      );

      print('Create channel response status: ${response.statusCode}');
      print('Create channel response body: ${response.body}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return Channel.fromJson(responseData['data']);
        }
      }
      throw Exception('Failed to create channel');
    } catch (e) {
      print('Error creating channel: $e');
      throw Exception('Failed to create channel: $e');
    }
  }

  // Generate shareable channel link
  Future<String> generateShareableLink(String channelId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channel/share/$channelId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Generate link response status: ${response.statusCode}');
      print('Generate link response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return responseData['data']['shareLink'];
        }
      }
      throw Exception('Failed to generate shareable link');
    } catch (e) {
      print('Error generating shareable link: $e');
      throw Exception('Failed to generate shareable link: $e');
    }
  }

  // Join channel using shared link
  Future<void> joinChannelViaLink(String shareToken, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channel/join-via-link'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'shareToken': shareToken,
        }),
      );

      print('Join via link response status: ${response.statusCode}');
      print('Join via link response body: ${response.body}');

      if (response.statusCode != 200) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(
            errorData['message'] ?? 'Failed to join channel via link');
      }
    } catch (e) {
      print('Error joining channel via link: $e');
      throw Exception('Failed to join channel via link: $e');
    }
  }
}
