import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const NeuronTrendsApp());

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class HfModel {
  final String id; // "owner/name"
  final int likes;
  final int downloads;
  final int trendingScore;
  final String? pipelineTag;
  final String? library;
  final String? license;
  final DateTime? createdAt;
  final List<String> tags;

  const HfModel({
    required this.id,
    required this.likes,
    required this.downloads,
    required this.trendingScore,
    this.pipelineTag,
    this.library,
    this.license,
    this.createdAt,
    this.tags = const [],
  });

  String get owner => id.contains('/') ? id.split('/').first : '';
  String get name => id.contains('/') ? id.split('/').last : id;
  Uri get url => Uri.parse('https://huggingface.co/$id');

  factory HfModel.fromJson(Map<String, dynamic> json) {
    final tags = (json['tags'] as List? ?? []).cast<String>();
    final license = tags
        .firstWhere((t) => t.startsWith('license:'), orElse: () => '')
        .replaceFirst('license:', '');
    return HfModel(
      id: json['id'] as String,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      downloads: (json['downloads'] as num?)?.toInt() ?? 0,
      trendingScore: (json['trendingScore'] as num?)?.toInt() ?? 0,
      pipelineTag: json['pipeline_tag'] as String?,
      library: json['library_name'] as String?,
      license: license.isEmpty ? null : license,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      tags: tags,
    );
  }
}

enum Feed {
  trending('Trending', 'trendingScore'),
  top('Top', 'likes'),
  fresh('New', 'createdAt');

  const Feed(this.label, this.sortKey);
  final String label;
  final String sortKey;
}

Future<List<HfModel>> fetchModels(Feed feed) async {
  final uri = Uri.https('huggingface.co', '/api/models', {
    'sort': feed.sortKey,
    'direction': '-1',
    'limit': '50',
  });
  final res = await http.get(uri).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw Exception('Hugging Face returned ${res.statusCode}');
  }
  final list = jsonDecode(res.body) as List;
  return [for (final m in list) HfModel.fromJson(m as Map<String, dynamic>)];
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

String compact(int n) {
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1)}M';
  }
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
  return '$n';
}

String timeAgo(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inDays >= 365) return '${d.inDays ~/ 365}y ago';
  if (d.inDays >= 30) return '${d.inDays ~/ 30}mo ago';
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  return '${d.inMinutes}m ago';
}

/// Modality family color for a pipeline tag — encodes what kind of model it is.
Color pipelineColor(String? tag, Brightness b) {
  final dark = b == Brightness.dark;
  if (tag == null) {
    return dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
  }
  if (tag.contains('image') || tag.contains('video') || tag.contains('depth')) {
    return dark ? const Color(0xFF34D399) : const Color(0xFF059669); // vision
  }
  if (tag.contains('audio') || tag.contains('speech')) {
    return dark ? const Color(0xFFF97316) : const Color(0xFFEA580C); // audio
  }
  if (tag.contains('text-generation') || tag.contains('conversational')) {
    return dark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5); // LLM
  }
  return dark ? const Color(0xFF22D3EE) : const Color(0xFF0891B2); // other
}

// ---------------------------------------------------------------------------
// Theme — HF yellow accent, warm paper light theme, OLED-black dark theme
// (true black saves power on OLED screens).
// ---------------------------------------------------------------------------

const hfYellow = Color(0xFFFFD21E);
const inkDark = Color(0xFF16161D);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme(
    brightness: b,
    primary: dark ? hfYellow : const Color(0xFF9A6B00),
    onPrimary: dark ? Colors.black : Colors.white,
    secondary: hfYellow,
    onSecondary: Colors.black,
    surface: dark ? Colors.black : Colors.white,
    onSurface: dark ? const Color(0xFFE7E5E0) : inkDark,
    error: dark ? const Color(0xFFFF6B6B) : const Color(0xFFB3261E),
    onError: Colors.white,
    surfaceContainerHighest:
        dark ? const Color(0xFF16161D) : const Color(0xFFF5F3EE),
    outlineVariant: dark ? const Color(0xFF23232C) : const Color(0xFFECE9E2),
    onSurfaceVariant: dark ? const Color(0xFF8B8B96) : const Color(0xFF6F6C64),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.5,
      space: 0.5,
    ),
  );
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class NeuronTrendsApp extends StatelessWidget {
  const NeuronTrendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neuron Trends',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const FeedPage(),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  Feed _feed = Feed.trending;
  late Future<List<HfModel>> _future = fetchModels(_feed);

  Future<void> _refresh() {
    HapticFeedback.lightImpact();
    final f = fetchModels(_feed);
    setState(() => _future = f);
    return f.then((_) {}, onError: (_) {});
  }

  void _setFeed(Feed feed) {
    if (feed == _feed) return;
    HapticFeedback.selectionClick();
    setState(() {
      _feed = feed;
      _future = fetchModels(feed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/icon/icon.png', width: 26, height: 26),
            ),
            const SizedBox(width: 10),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: 'neuron',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: ' trends',
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ]),
              style: const TextStyle(fontSize: 19),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  for (final f in Feed.values) ...[
                    _FeedChip(
                      label: f.label,
                      selected: f == _feed,
                      onTap: () => _setFeed(f),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<HfModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorView(onRetry: _refresh);
          }
          if (!snap.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(strokeWidth: 2.5, color: hfYellow),
            );
          }
          final models = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            color: scheme.primary,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: models.length,
              separatorBuilder: (_, i) => const Divider(indent: 52),
              itemBuilder: (context, i) => _ModelRow(
                rank: i + 1,
                model: models[i],
                feed: _feed,
                onTap: () => _showDetail(context, models[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, HfModel model) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DetailSheet(model: model),
    );
  }
}

class _FeedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FeedChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? hfYellow : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? hfYellow : scheme.outlineVariant,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.black : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row — HN-style: rank, title, meta line. Text only: no avatars, no images.
// ---------------------------------------------------------------------------

class _ModelRow extends StatelessWidget {
  final int rank;
  final HfModel model;
  final Feed feed;
  final VoidCallback onTap;

  const _ModelRow({
    required this.rank,
    required this.model,
    required this.feed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tagColor = pipelineColor(model.pipelineTag, scheme.brightness);
    final score = switch (feed) {
      Feed.trending => model.trendingScore,
      Feed.top => model.likes,
      Feed.fresh => model.likes,
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '$rank',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: rank <= 3 ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${model.owner}/',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: model.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ]),
                    style: const TextStyle(
                        fontSize: 15, height: 1.35, letterSpacing: -0.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    child: Row(
                      children: [
                        Text('▲ ${compact(score)}',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            )),
                        if (model.pipelineTag != null) ...[
                          const Text('  ·  '),
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                                color: tagColor, shape: BoxShape.circle),
                          ),
                          Flexible(
                            child: Text(
                              model.pipelineTag!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const Text('  ·  '),
                        Text(timeAgo(model.createdAt)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '↓ ${compact(model.downloads)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail sheet
// ---------------------------------------------------------------------------

class _DetailSheet extends StatelessWidget {
  final HfModel model;

  const _DetailSheet({required this.model});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tagColor = pipelineColor(model.pipelineTag, scheme.brightness);
    final cleanTags =
        model.tags.where((t) => !t.contains(':')).take(14).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              model.owner,
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
            Text(
              model.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.2,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                    label: 'trending',
                    value: '▲ ${compact(model.trendingScore)}',
                    color: scheme.primary),
                _Stat(label: 'likes', value: compact(model.likes)),
                _Stat(label: 'downloads', value: compact(model.downloads)),
                _Stat(label: 'created', value: timeAgo(model.createdAt)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (model.pipelineTag != null)
                  _Pill(text: model.pipelineTag!, dot: tagColor),
                if (model.library != null) _Pill(text: model.library!),
                if (model.license != null)
                  _Pill(text: '${model.license} license'),
                for (final t in cleanTags) _Pill(text: t),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: hfYellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () =>
                    launchUrl(model.url, mode: LaunchMode.externalApplication),
                child: const Text(
                  'Open on Hugging Face',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color ?? scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color? dot;

  const _Pill({required this.text, this.dot});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ],
          Text(text, style: TextStyle(fontSize: 12, color: scheme.onSurface)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Couldn't reach Hugging Face",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface)),
          const SizedBox(height: 4),
          Text('Check your connection and try again',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
