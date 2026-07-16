import 'package:flutter_test/flutter_test.dart';
import 'package:neuron_trends/main.dart';

void main() {
  test('parses HF API model json', () {
    final m = HfModel.fromJson({
      'id': 'prism-ml/Ternary-Bonsai-27B-gguf',
      'likes': 513,
      'downloads': 74007,
      'trendingScore': 499,
      'pipeline_tag': 'text-generation',
      'library_name': 'llama.cpp',
      'createdAt': '2026-07-04T00:24:01.000Z',
      'tags': ['gguf', 'license:apache-2.0', 'region:us'],
    });
    expect(m.owner, 'prism-ml');
    expect(m.name, 'Ternary-Bonsai-27B-gguf');
    expect(m.license, 'apache-2.0');
    expect(m.url.toString(),
        'https://huggingface.co/prism-ml/Ternary-Bonsai-27B-gguf');
  });

  test('survives missing optional fields', () {
    final m = HfModel.fromJson({'id': 'solo-model'});
    expect(m.owner, '');
    expect(m.name, 'solo-model');
    expect(m.likes, 0);
    expect(m.license, isNull);
    expect(m.createdAt, isNull);
  });

  test('compact number formatting', () {
    expect(compact(4), '4');
    expect(compact(999), '999');
    expect(compact(1200), '1.2k');
    expect(compact(74007), '74k');
    expect(compact(559267), '559k');
    expect(compact(1500000), '1.5M');
  });

  test('detail parsing: quants, params, gated', () {
    final d = HfModelDetail.fromJson({
      'gguf': {'total': 3645856513, 'architecture': 'dspark', 'context_length': 4096},
      'cardData': {'base_model': 'Qwen/Qwen3.6-27B'},
      'gated': false,
      'siblings': [
        {'rfilename': 'README.md', 'size': 100},
        {'rfilename': 'm-Q2_0.gguf', 'size': 700},
        {'rfilename': 'm-Q8_0-00001-of-00002.gguf', 'size': 400},
        {'rfilename': 'm-Q8_0-00002-of-00002.gguf', 'size': 500},
        {'rfilename': 'm.F16.gguf', 'size': 1600},
        {'rfilename': 'm-f16-extra.gguf', 'size': 100},
      ],
    });
    expect(d.paramCount, 3645856513);
    expect(d.architecture, 'dspark');
    expect(d.contextLength, 4096);
    expect(d.baseModels, ['Qwen/Qwen3.6-27B']);
    expect(d.gated, false);
    expect(d.fileCount, 6);
    final quants = {for (final (n, s) in d.quants) n: s};
    expect(quants, {'Q2_0': 700, 'Q8_0': 900, 'F16': 1700});
  });

  test('params and bytes labels', () {
    expect(paramsLabel(3645856513), '3.6B');
    expect(paramsLabel(27000000000), '27B');
    expect(paramsLabel(770000000), '770M');
    expect(bytesLabel(7291885792), '6.8 GB');
    expect(bytesLabel(38400000), '37 MB');
  });

  test('timeAgo buckets', () {
    final now = DateTime.now();
    expect(timeAgo(null), '');
    expect(timeAgo(now.subtract(const Duration(minutes: 5))), '5m ago');
    expect(timeAgo(now.subtract(const Duration(hours: 3))), '3h ago');
    expect(timeAgo(now.subtract(const Duration(days: 12))), '12d ago');
    expect(timeAgo(now.subtract(const Duration(days: 400))), '1y ago');
  });
}
