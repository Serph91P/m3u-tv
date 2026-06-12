import 'domain_models.dart';

class ResumeService {
  ResumeService({
    Map<String, Object?>? memory,
    this.promptThreshold = const Duration(seconds: 30),
  }) : _memory = memory ?? <String, Object?>{};

  final Map<String, Object?> _memory;
  final Duration promptThreshold;

  Future<void> save(Progress progress) async {
    _memory[_key(progress.viewerId, progress.contentType, progress.streamId)] =
        progress;
  }

  Future<Progress?> load(
    String viewerId,
    ContentType contentType,
    int streamId,
  ) async {
    return _memory[_key(viewerId, contentType, streamId)] as Progress?;
  }

  Future<List<Progress>> all(String viewerId) async {
    return _memory.values
        .whereType<Progress>()
        .where((Progress progress) => progress.viewerId == viewerId)
        .toList(growable: false);
  }

  Future<bool> shouldPromptResume(
    String viewerId,
    ContentType contentType,
    int streamId,
  ) async {
    final progress = await load(viewerId, contentType, streamId);
    return progress != null &&
        !progress.completed &&
        progress.positionSeconds >= promptThreshold.inSeconds;
  }

  String _key(String viewerId, ContentType contentType, int streamId) =>
      'm3ue_resume_${viewerId}_${contentType.wireName}_$streamId';
}
