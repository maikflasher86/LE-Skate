import 'package:flutter/material.dart';
import 'package:inliner2/generated/build_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Shared logic to load the app version + build timestamp once and expose
/// them via [version] and [build]. Used by both the compact sheet and the
/// full about page to avoid duplicating the PackageInfo-loading code.
mixin _VersionInfoMixin<T extends StatefulWidget> on State<T> {
  String version = '-';
  String buildInfo = '-';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          version = info.version;
          buildInfo = '#${info.buildNumber} @ $kBuildTimestamp';
        });
      }
    });
  }
}

/// Compact bottom sheet for imprint.
class AboutSheet extends StatefulWidget {
  const AboutSheet({super.key});
  @override
  State<AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends State<AboutSheet> with _VersionInfoMixin {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _Row(icon: Icons.code, label: 'Entwickler', value: 'Maik Neumann'),
          //const SizedBox(height: 10),
          //_Row(
          //  icon: Icons.cloud_outlined,
          //  label: 'Wetterdaten',
          //  value: 'Open-Meteo (open-meteo.com)',
          //),
          //const SizedBox(height: 10),
          //_Row(
          //  icon: Icons.lock_outline,
          //  label: 'Datenschutz',
          //  value: 'Keine Speicherung personenbezogener Daten',
          //),
          const SizedBox(height: 10),
          _Row(icon: Icons.tag_rounded, label: 'Version', value: version),
          const SizedBox(height: 10),
          _Row(
            icon: Icons.schedule_rounded,
            label: 'Build',
            value: buildInfo,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF3B7BFF)),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label  ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with _VersionInfoMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF060D1F), Color(0xFF0B1A3E), Color(0xFF112258)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white70,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  children: [
                    _Section(
                      icon: Icons.code,
                      title: 'Entwickler',
                      content: 'Maik Neumann',
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: Icons.cloud_outlined,
                      title: 'Wetterdaten',
                      content:
                          'Wetterdaten werden von Open-Meteo bereitgestellt.\nhttps://open-meteo.com',
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: Icons.lock_outline,
                      title: 'Datenschutz',
                      content:
                          'Diese App speichert keine personenbezogenen Daten und überträgt keine Nutzerdaten an Dritte.',
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: Icons.tag_rounded,
                      title: 'Version',
                      content: version,
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: Icons.schedule_rounded,
                      title: 'Build-Zeitstempel',
                      content: buildInfo,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.content,
  });
  final IconData icon;
  final String title;
  final String content;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF3B7BFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
