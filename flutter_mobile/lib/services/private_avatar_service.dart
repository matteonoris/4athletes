import 'package:supabase_flutter/supabase_flutter.dart';

class PrivateAvatarService {
  final SupabaseClient client;
  PrivateAvatarService(this.client);
  static const prefix = 'storage:avatars/';

  // Store an object path, never an expiring signed link.
  static String reference(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null) {
      for (final marker in [
        '/storage/v1/object/sign/avatars/',
        '/storage/v1/object/public/avatars/'
      ]) {
        final index = uri.path.indexOf(marker);
        if (index >= 0)
          return '$prefix${Uri.decodeComponent(uri.path.substring(index + marker.length))}';
      }
    }
    return value;
  }

  Future<String> resolve(String value) async {
    final path = reference(value);
    if (!path.startsWith(prefix)) return value;
    try {
      return await client.storage
          .from('avatars')
          .createSignedUrl(path.substring(prefix.length), 1800);
    } catch (_) {
      return '';
    }
  }
}
