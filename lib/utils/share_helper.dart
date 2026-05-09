import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/bill_provider.dart';

class ShareHelper {
  static String generateReport(BillProvider provider) {
    final buf = StringBuffer();
    final sym = provider.currency.symbol;
    final cat = provider.category.name;

    buf.writeln('$cat — Итоги:');
    buf.writeln('');

    for (final person in provider.people) {
      final total = provider.getPersonTotal(person.id);
      final items = provider.getPersonItems(person.id);
      final itemNames = items.map((i) => i.name).join(', ');
      buf.writeln(
        '${person.name}: ${total.toStringAsFixed(0)} $sym'
        '${itemNames.isNotEmpty ? ' ($itemNames)' : ''}',
      );
    }

    buf.writeln('');
    buf.writeln('Общий счёт: ${provider.total.toStringAsFixed(0)} $sym');
    if (provider.serviceChargeEnabled) {
      buf.writeln(
        'Обслуживание: ${provider.serviceChargePercent.toStringAsFixed(0)}%'
        ' (${provider.serviceChargeAmount.toStringAsFixed(0)} $sym)',
      );
    }

    buf.writeln('');
    buf.writeln('Разделено в Fair Splitter');

    return buf.toString();
  }

  static Future<void> shareViaSystem(String text) async {
    await Share.share(text);
  }

  static Future<void> shareViaTelegram(String text) async {
    final encoded = Uri.encodeComponent(text);
    final url = Uri.parse('tg://msg?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Fallback to web Telegram
      final webUrl = Uri.parse('https://t.me/share/url?text=$encoded');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> shareViaWhatsApp(String text) async {
    final encoded = Uri.encodeComponent(text);
    final url = Uri.parse('whatsapp://send?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final webUrl = Uri.parse('https://wa.me/?text=$encoded');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}
