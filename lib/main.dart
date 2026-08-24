import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Background audio setup
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.auramusic.app.channel.audio',
    androidNotificationChannelName: 'Aura Music Playback',
    androidNotificationOngoing: true,
  );

  // Initialize Ads
  MobileAds.instance.initialize();

  // Try Firebase safely
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase not configured: $e");
  }

  runApp(const AuraMusicApp());
}

class Song {
  final String id;
  final String title;
  final String artist;
  final String url;
  final String artwork;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    required this.artwork,
  });
}

class AuraMusicApp extends StatelessWidget {
  const AuraMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura Beats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00E5FF),
        ),
      ),
      home: const MusicHomeScreen(),
    );
  }
}

class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen({super.key});

  @override
  State<MusicHomeScreen> createState() => _MusicHomeScreenState();
}

class _MusicHomeScreenState extends State<MusicHomeScreen> {
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();
  
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  final List<Song> _defaultSongs = [
    Song(
      id: "1",
      title: "Munur Mai",
      artist: "Gangadhar & Murmu",
      url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
      artwork: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80",
    ),
    Song(
      id: "2",
      title: "Mayam Gada",
      artist: "Santali Beats",
      url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
      artwork: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80",
    ),
    Song(
      id: "3",
      title: "Neon Horizon",
      artist: "Cyber Synth",
      url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
      artwork: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80",
    ),
  ];

  List<Song> _allSongs = [];
  List<Song> _filteredSongs = [];
  final Set<String> _favorites = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _allSongs = _defaultSongs;
    _filteredSongs = _defaultSongs;
    _loadCloudSongs();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Banner ID
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          setState(() => _isBannerAdReady = false);
        },
      ),
    )..load();
  }

  void _loadCloudSongs() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('songs').get();
      if (snapshot.docs.isNotEmpty) {
        final cloudSongs = snapshot.docs.map((doc) {
          final data = doc.data();
          return Song(
            id: doc.id,
            title: data['title'] ?? 'Unknown',
            artist: data['artist'] ?? 'Unknown Artist',
            url: data['url'] ?? '',
            artwork: data['artwork'] ?? '',
          );
        }).toList();

        setState(() {
          _allSongs = cloudSongs;
          _filteredSongs = cloudSongs;
        });
      }
    } catch (e) {
      debugPrint("Firestore fetch fallback to default: $e");
    }
  }

  void _filterSongs(String query) {
    setState(() {
      _filteredSongs = _allSongs
          .where((s) =>
              s.title.toLowerCase().contains(query.toLowerCase()) ||
              s.artist.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _playSong(int index) async {
    setState(() => _currentIndex = index);
    final song = _filteredSongs[index];

    try {
      final audioSource = AudioSource.uri(
        Uri.parse(song.url),
        tag: MediaItem(
          id: song.id,
          title: song.title,
          artist: song.artist,
          artUri: Uri.parse(song.artwork),
        ),
      );
      await _player.setAudioSource(audioSource);
      _player.play();
    } catch (e) {
      debugPrint("Playback error: $e");
    }
  }

  void _nextSong() {
    if (_currentIndex < _filteredSongs.length - 1) {
      _playSong(_currentIndex + 1);
    } else {
      _playSong(0);
    }
  }

  void _prevSong() {
    if (_currentIndex > 0) {
      _playSong(_currentIndex - 1);
    } else {
      _playSong(_filteredSongs.length - 1);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _searchController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Song? currentSong = _filteredSongs.isNotEmpty && _currentIndex < _filteredSongs.length
        ? _filteredSongs[_currentIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.graphic_eq, color: Color(0xFF00E5FF), size: 28),
            SizedBox(width: 10),
            Text("Aura Beats", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSongs,
              decoration: InputDecoration(
                hintText: "Search songs, artists...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
                filled: true,
                fillColor: const Color(0xFF161B22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSongs.length,
              itemBuilder: (context, index) {
                final song = _filteredSongs[index];
                final isSelected = _currentIndex == index;
                final isFav = _favorites.contains(song.title);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        song.artwork,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[800],
                          child: const Icon(Icons.music_note, color: Color(0xFF00E5FF)),
                        ),
                      ),
                    ),
                    title: Text(
                      song.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFF00E5FF) : Colors.white,
                      ),
                    ),
                    subtitle: Text(song.artist, style: const TextStyle(color: Colors.grey)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.redAccent : Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isFav) {
                                _favorites.remove(song.title);
                              } else {
                                _favorites.add(song.title);
                              }
                            });
                          },
                        ),
                        StreamBuilder<PlayerState>(
                          stream: _player.playerStateStream,
                          builder: (context, snapshot) {
                            final state = snapshot.data;
                            final playing = state?.playing ?? false;
                            final isThisPlaying = isSelected && playing;

                            return IconButton(
                              icon: Icon(
                                isThisPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: const Color(0xFF00E5FF),
                                size: 36,
                              ),
                              onPressed: () {
                                if (isSelected) {
                                  playing ? _player.pause() : _player.play();
                                } else {
                                  _playSong(index);
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (currentSong != null)
            GestureDetector(
              onTap: () => _openFullPlayer(context, currentSong),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF161B22),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<Duration?>(
                      stream: _player.positionStream,
                      builder: (context, posSnap) {
                        return ProgressBar(
                          progress: posSnap.data ?? Duration.zero,
                          total: _player.duration ?? Duration.zero,
                          progressBarColor: const Color(0xFF00E5FF),
                          baseBarColor: Colors.grey[800],
                          thumbColor: const Color(0xFF00E5FF),
                          thumbRadius: 4,
                          timeLabelTextStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                          onSeek: (duration) => _player.seek(duration),
                        );
                      },
                    ),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            currentSong.artwork,
                            width: 45,
                            height: 45,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                              ),
                              Text(currentSong.artist, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous, color: Colors.white),
                          onPressed: _prevSong,
                        ),
                        StreamBuilder<PlayerState>(
                          stream: _player.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            return IconButton(
                              icon: Icon(
                                playing ? Icons.pause_circle : Icons.play_circle,
                                color: const Color(0xFF00E5FF),
                                size: 36,
                              ),
                              onPressed: () => playing ? _player.pause() : _player.play(),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                          onPressed: _nextSong,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // Clean AdMob Banner
          if (_isBannerAdReady && _bannerAd != null)
            Container(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  void _openFullPlayer(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10))),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  song.artwork,
                  width: 250,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
              Column(
                children: [
                  Text(song.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(song.artist, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
              StreamBuilder<Duration?>(
                stream: _player.positionStream,
                builder: (context, posSnap) {
                  return ProgressBar(
                    progress: posSnap.data ?? Duration.zero,
                    total: _player.duration ?? Duration.zero,
                    progressBarColor: const Color(0xFF00E5FF),
                    baseBarColor: Colors.grey[800],
                    thumbColor: const Color(0xFF00E5FF),
                    onSeek: (d) => _player.seek(d),
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(icon: const Icon(Icons.skip_previous, size: 36), onPressed: _prevSong),
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 64, color: const Color(0xFF00E5FF)),
                        onPressed: () => playing ? _player.pause() : _player.play(),
                      );
                    },
                  ),
                  IconButton(icon: const Icon(Icons.skip_next, size: 36), onPressed: _nextSong),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
