import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:inliner2/models/location.dart';

/// Second rain radar view based on Windy.com embedding. Windy shows the
/// rain radar including its own timeline (past + forecast) and
/// playback controls directly in the embedded widget.
///
/// Note: `webview_flutter` officially only supports Android/iOS/macOS –
/// there is no plugin backend available for Windows/Linux.
class RainRadarSheet extends StatefulWidget {
  const RainRadarSheet({super.key, required this.location});

  final Location location;

  @override
  State<RainRadarSheet> createState() => _RainRadarSheetState();
}

class _RainRadarSheetState extends State<RainRadarSheet> {
  late final WebViewController _controller;

  String get _embedUrl {
    final lat = widget.location.lat;
    final lon = widget.location.lon;
    return 'https://embed.windy.com/embed2.html'
        '?lat=$lat&lon=$lon'
        '&detailLat=$lat&detailLon=$lon'
        '&width=650'
        '&height=450'
        '&zoom=12'
        '&level=surface'
        '&overlay=rain'
        '&product=ecmwf'
        //'&product=icon'
        '&menu='
        '&message=true'
        '&marker=true'
        '&calendar=now'
        '&pressure='
        '&type=map'
        '&location=coordinates'
        '&detail=false'
        '&metricWind=default'
        '&metricTemp=default'
        '&radarRange=-1';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..loadRequest(Uri.parse(_embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 20 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Windy Regenradar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.location.label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}
