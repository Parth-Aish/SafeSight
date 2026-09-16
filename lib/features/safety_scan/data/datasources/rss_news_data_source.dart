import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class NewsHeadline {
  final String title;
  final String source;
  final DateTime? publishedAt;

  const NewsHeadline(
      {required this.title, required this.source, this.publishedAt});
}

class RssNewsDataSource {
  final http.Client _client;

  RssNewsDataSource({http.Client? client}) : _client = client ?? http.Client();

  Future<List<NewsHeadline>> fetchRecentHeadlines(String city) async {
    if (city.trim().isEmpty) return const [];

    final query = '(${city.trim()} crime OR ${city.trim()} safety) when:7d';
    final uri = Uri.parse(
      'https://news.google.com/rss/search?q=${Uri.encodeComponent(query)}&hl=en-IN&gl=IN&ceid=IN:en',
    );
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('News provider returned HTTP ${response.statusCode}.');
    }

    final document = XmlDocument.parse(response.body);
    return document
        .findAllElements('item')
        .map((item) {
          final title = item.getElement('title')?.innerText.trim() ?? '';
          final source =
              item.getElement('source')?.innerText.trim() ?? 'Google News';
          final rawDate = item.getElement('pubDate')?.innerText;
          return NewsHeadline(
            title: title,
            source: source,
            publishedAt: rawDate == null ? null : DateTime.tryParse(rawDate),
          );
        })
        .where((headline) => headline.title.isNotEmpty)
        .take(20)
        .toList();
  }
}
