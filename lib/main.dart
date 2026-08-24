import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  runApp(const AuraMusicApp());
}

class AuraMusicApp extends StatelessWidget {
  const AuraMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aura Beats',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090B10),
      ),
      home: const UserStreamScreen(),
    );
  }
}

class UserStreamScreen extends StatefulWidget {
  const UserStreamScreen({super.key});

  @override
  State<UserStreamScreen> createState() => _UserStreamScreenState();
}

class _UserStreamScreenState extends State<UserStreamScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Map<String, dynamic>? _currentSong;
  bool _isPlaying = false;
  
  BannerAd? _bottomBannerAd;
  bool _isBannerLoaded = false;
  InterstitialAd? _interstitialAd;
  int _songChangeCount = 0;

  final String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  final String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadInterstitialAd();

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
  }

  void _loadBannerAd() {
    _bottomBannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner load failed: $error');
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void _triggerAdOnSongChange() {
    _songChangeCount++;
    if (_songChangeCount >= 3) {
      if (_interstitialAd != null) {
        _interstitialAd!.show();
        _songChangeCount = 0;
      }
    }
  }

  void _playSong(Map<String, dynamic> song, String docId) async {
    try {
      if (_currentSong?['audioUrl'] == song['audioUrl']) {
        if (_isPlaying) {
          _audioPlayer.pause();
        } else {
          _audioPlayer.play();
        }
      } else {
        setState(() => _currentSong = song);
        await _audioPlayer.setUrl(song['audioUrl']);
        _audioPlayer.play();

        FirebaseFirestore.instance.collection('songs').doc(docId).update({
          'playCount': FieldValue.increment(1)
        });

        _triggerAdOnSongChange();
      }
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _bottomBannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.graphic_eq, color: Colors.cyanAccent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Aura Beats',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('songs').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                }

                final songs = snap.data!.docs;

                if (songs.isEmpty) {
                  return const Center(
                    child: Text('No tracks available yet.', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
                  itemCount: songs.length,
                  itemBuilder: (_, i) {
                    final s = songs[i].data() as Map<String, dynamic>;
                    final isCurrent = _currentSong?['audioUrl'] == s['audioUrl'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFF16202C) : const Color(0xFF10141C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrent ? Colors.cyanAccent.withOpacity(0.4) : Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            s['imageUrl'] ?? '',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.cyanAccent),
                          ),
                        ),
                        title: Text(
                          s['title'] ?? 'Untitled',
                          style: TextStyle(
                            color: isCurrent ? Colors.cyanAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          s['artist'] ?? 'Unknown Artist',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isCurrent && _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: Colors.cyanAccent,
                            size: 36,
                          ),
                          onPressed: () => _playSong(s, songs[i].id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (_currentSong != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141A23),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _currentSong!['imageUrl'] ?? '',
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.cyanAccent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentSong!['title'] ?? '',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currentSong!['artist'] ?? '',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.cyanAccent,
                      size: 30,
                    ),
                    onPressed: () => _isPlaying ? _audioPlayer.pause() : _audioPlayer.play(),
                  ),
                ],
              ),
            ),

          if (_isBannerLoaded && _bottomBannerAd != null)
            Container(
              width: _bottomBannerAd!.size.width.toDouble(),
              height: _bottomBannerAd!.size.height.toDouble(),
              alignment: Alignment.center,
              child: AdWidget(ad: _bottomBannerAd!),
            ),
        ],
      ),
    );
  }
}
