import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bunny_stream/flutter_bunny_stream.dart';
import 'package:flutter_bunny_stream/src/bunny_stream_api.dart';
import 'package:flutter_bunny_stream/src/models/bunny_video.dart';
import 'package:flutter_bunny_stream/src/widgets/bunny_camera.dart';
import 'package:flutter_bunny_stream/src/widgets/bunny_video_player.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request camera and microphone permissions
  await [
    Permission.camera,
    Permission.microphone,
    Permission.storage,
    Permission.photos,
  ].request();
  
  runApp(const BunnyStreamExampleApp());
}

class BunnyStreamExampleApp extends StatelessWidget {
  const BunnyStreamExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bunny Stream Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BunnyStreamHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BunnyStreamHomePage extends StatefulWidget {
  const BunnyStreamHomePage({super.key});

  @override
  State<BunnyStreamHomePage> createState() => _BunnyStreamHomePageState();
}

class _BunnyStreamHomePageState extends State<BunnyStreamHomePage> with SingleTickerProviderStateMixin {
  late final BunnyStreamApi _bunnyStream;
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  
  // Form fields
  final _accessKeyController = TextEditingController();
  final _libraryIdController = TextEditingController();
  final _cdnHostnameController = TextEditingController();
  
  // State
  bool _isInitialized = false;
  bool _isLoading = false;
  List<BunnyVideo> _videos = [];
  BunnyVideo? _selectedVideo;
  String? _videoUrl;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeBunnyStream();
  }
  
  @override
  void dispose() {
    _accessKeyController.dispose();
    _libraryIdController.dispose();
    _cdnHostnameController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeBunnyStream() async {
    // In a real app, you should store these securely
    _accessKeyController.text = const String.fromEnvironment('BUNNY_ACCESS_KEY', defaultValue: '');
    _libraryIdController.text = const String.fromEnvironment('BUNNY_LIBRARY_ID', defaultValue: '');
    _cdnHostnameController.text = const String.fromEnvironment('BUNNY_CDN_HOSTNAME', defaultValue: '');
    
    if (_accessKeyController.text.isNotEmpty && _libraryIdController.text.isNotEmpty) {
      await _initializeWithCredentials(
        _accessKeyController.text,
        int.tryParse(_libraryIdController.text) ?? 0,
        _cdnHostnameController.text.isNotEmpty ? _cdnHostnameController.text : null,
      );
    }
  }
  
  Future<void> _initializeWithCredentials(String accessKey, int libraryId, String? cdnHostname) async {
    if (accessKey.isEmpty || libraryId == 0) {
      _showSnackBar('Please provide valid access key and library ID');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      _bunnyStream = await FlutterBunnyStream.create(
        accessKey: accessKey,
        libraryId: libraryId,
        cdnHostname: cdnHostname,
      );
      
      await _loadVideos();
      
      setState(() => _isInitialized = true);
      _showSnackBar('Successfully connected to Bunny Stream');
    } catch (e) {
      _showSnackBar('Failed to initialize Bunny Stream: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _loadVideos() async {
    if (!_isInitialized) return;
    
    setState(() => _isLoading = true);
    
    try {
      final videos = await _bunnyStream.listVideos();
      if (mounted) {
        setState(() {
          _videos = videos;
          if (_videos.isNotEmpty) {
            _selectedVideo = _videos.first;
            _videoUrl = _bunnyStream.getPlaybackUrl(_selectedVideo!.id);
          }
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load videos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _handleVideoSelected(BunnyVideo video) {
    setState(() {
      _selectedVideo = video;
      _videoUrl = _bunnyStream.getPlaybackUrl(video.id);
    });
  }
  
  Future<void> _deleteVideo(String videoId) async {
    if (!_isInitialized) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text('Are you sure you want to delete this video?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _bunnyStream.deleteVideo(videoId);
      await _loadVideos();
      _showSnackBar('Video deleted successfully');
    } catch (e) {
      _showSnackBar('Failed to delete video: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _showSnackBar(String message) {
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bunny Stream Demo'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.video_library), text: 'Library'),
              Tab(icon: Icon(Icons.videocam), text: 'Record'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isInitialized
                ? _buildMainContent()
                : _buildSetupScreen(),
      ),
    );
  }
  
  Widget _buildSetupScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.video_library, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Bunny Stream Setup',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _accessKeyController,
              decoration: const InputDecoration(
                labelText: 'Access Key',
                border: OutlineInputBorder(),
                hintText: 'Enter your Bunny Stream access key',
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _libraryIdController,
              decoration: const InputDecoration(
                labelText: 'Library ID',
                border: OutlineInputBorder(),
                hintText: 'Enter your Bunny Stream library ID',
              ),
              keyboardType: TextInputType.number,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cdnHostnameController,
              decoration: const InputDecoration(
                labelText: 'CDN Hostname (Optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., your-cdn.b-cdn.net',
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        await _initializeWithCredentials(
                          _accessKeyController.text,
                          int.tryParse(_libraryIdController.text) ?? 0,
                          _cdnHostnameController.text.isNotEmpty ? _cdnHostnameController.text : null,
                        );
                      }
                    },
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Connect to Bunny Stream'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMainContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        // Library Tab
        _buildLibraryTab(),
        // Record Tab
        _buildRecordTab(),
        // Settings Tab
        _buildSettingsTab(),
      ],
    );
  }
  
  Widget _buildLibraryTab() {
    if (_videos.isEmpty) {
      return const Center(child: Text('No videos found'));
    }
    
    return Column(
      children: [
        // Video Player
        if (_selectedVideo != null && _videoUrl != null)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BunnyVideoPlayer(
              videoUrl: _videoUrl!,
              autoplay: true,
              looping: false,
              onInitialized: () {
                debugPrint('Video player initialized');
              },
              onEnded: () {
                debugPrint('Video playback completed');
              },
              onError: (error) {
                _showSnackBar('Error playing video: $error');
              },
            ),
          ),
        
        // Video List
        Expanded(
          child: ListView.builder(
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              final video = _videos[index];
              return ListTile(
                leading: video.thumbnailUrl != null
                    ? Image.network(
                        video.thumbnailUrl!,
                        width: 80,
                        height: 45,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.videocam, size: 40),
                      )
                    : const Icon(Icons.videocam, size: 40),
                title: Text(video.title),
                subtitle: Text(
                  '${video.duration != null ? '${(video.duration! / 60).floor()}m ${(video.duration! % 60).toInt()}s' : '0m 0s'} • ${_formatFileSize(video.size ?? 0)}',
                ),
                selected: _selectedVideo?.id == video.id,
                onTap: () => _handleVideoSelected(video),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteVideo(video.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecordTab() {
    if (!_isInitialized) {
      return const Center(child: Text('Please configure Bunny Stream in Settings'));
    }
    
    return BunnyCamera(
      bunnyStreamApi: _bunnyStream,
      onVideoUploaded: (videoId) {
        _showSnackBar('Video uploaded successfully! ID: $videoId');
        _loadVideos();
        _tabController.animateTo(0); // Switch to Library tab
      },
      onError: (error) {
        _showSnackBar('Error: $error');
      },
      maxDuration: const Duration(seconds: 60),
      resolutionPreset: ResolutionPreset.high,
      recordButtonColor: Colors.red,
      stopButtonColor: Colors.red,
      uploadButtonColor: Colors.green,
      retryButtonColor: Colors.orange,
    );
  }
  
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bunny Stream Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _accessKeyController,
            decoration: const InputDecoration(
              labelText: 'Access Key',
              border: OutlineInputBorder(),
            ),
            enabled: false, // Prevent editing while connected
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _libraryIdController,
            decoration: const InputDecoration(
              labelText: 'Library ID',
              border: OutlineInputBorder(),
            ),
            enabled: false, // Prevent editing while connected
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cdnHostnameController,
            decoration: const InputDecoration(
              labelText: 'CDN Hostname',
              border: OutlineInputBorder(),
            ),
            enabled: false, // Prevent editing while connected
          ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _isInitialized = false;
                  _accessKeyController.clear();
                  _libraryIdController.clear();
                  _cdnHostnameController.clear();
                  _videos.clear();
                  _selectedVideo = null;
                  _videoUrl = null;
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Disconnect'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'About',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Version: 1.0.0'),
          const SizedBox(height: 4),
          Text('Platform: ${Platform.operatingSystem}'),
        ],
      ),
    );
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
