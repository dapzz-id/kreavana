import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../app/theme.dart';

class KreavanaImage extends StatefulWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isAvatar;

  const KreavanaImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.isAvatar = false,
  });

  @override
  State<KreavanaImage> createState() => _KreavanaImageState();
}

class _KreavanaImageState extends State<KreavanaImage> {
  bool _isDeleted = false;
  bool _isChecking = false;

  void _checkStatus() async {
    if (widget.url == null || widget.url!.isEmpty) return;
    if (_isChecking) return;

    setState(() => _isChecking = true);
    try {
      // Parse identifier (UUID or stored_name) from URL
      final uri = Uri.tryParse(widget.url!);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final filename = uri.pathSegments.last; // e.g. abc-123.jpg
        final res = await StorageService.checkFileStatus(filename);
        if (res['deleted'] == true && mounted) {
          setState(() {
            _isDeleted = true;
          });
        }
      }
    } catch (e) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Widget _buildDeletedPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.isAvatar ? Icons.person_off : Icons.broken_image, color: Colors.grey.shade400, size: widget.isAvatar ? 24 : 32),
            if (!widget.isAvatar)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text('Media telah dihapus', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url == null || widget.url!.isEmpty) {
      return widget.errorWidget ?? _buildDeletedPlaceholder();
    }

    if (_isDeleted) {
      return widget.errorWidget ?? _buildDeletedPlaceholder();
    }

    final resolvedUrl = ApiService.resolveAssetUrl(widget.url!);

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => widget.placeholder ?? Container(color: Colors.grey.shade100),
      errorWidget: (context, url, error) {
        // If HTTP fails (e.g. 404 because file was physically deleted), check the API status
        // to confirm if it was intentionally deleted from Storage Manager
        _checkStatus();
        
        return widget.errorWidget ?? _buildDeletedPlaceholder();
      },
    );
  }
}

class KreavanaAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final Color? backgroundColor;

  const KreavanaAvatar({
    super.key,
    required this.url,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.grey.shade200,
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? Icon(Icons.person, color: AppTheme.primaryPurple, size: radius)
          : KreavanaImage(
              url: url,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              isAvatar: true,
            ),
    );
  }
}
