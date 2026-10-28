import 'package:flutter/material.dart';
import 'package:inliner2/generated/build_info.dart';
import 'package:inliner2/ui/app_colors.dart';
import 'package:inliner2/ui/widgets/sheet_scaffold.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Compact bottom sheet for imprint.
class AboutSheet extends StatefulWidget {
  const AboutSheet({super.key});
  @override
  State<AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends State<AboutSheet> {
  String _version = '-';
  String _buildInfo = '-';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _version = info.version;
          _buildInfo = '#${info.buildNumber} @ $kBuildTimestamp';
        });
      }
    });
  }

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
          const SheetDragHandle(),
          const SizedBox(height: 16),
          const SheetTitle('About'),
          const SizedBox(height: 16),
          _Row(icon: Icons.code, label: 'Entwickler', value: 'Maik Neumann'),
          const SizedBox(height: 10),
          _Row(icon: Icons.tag_rounded, label: 'Version', value: _version),
          const SizedBox(height: 10),
          _Row(icon: Icons.schedule_rounded, label: 'Build', value: _buildInfo),
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
        Icon(icon, size: 16, color: brandBlue),
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
