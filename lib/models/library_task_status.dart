class LibraryTaskStatus {
  const LibraryTaskStatus({
    required this.taskType,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.totalFiles,
    required this.processedFiles,
    required this.updatedFiles,
    required this.skippedFiles,
    required this.deletedFiles,
    required this.failedFiles,
    required this.lastError,
  });

  final String taskType;
  final String status;
  final int startedAt;
  final int finishedAt;
  final int totalFiles;
  final int processedFiles;
  final int updatedFiles;
  final int skippedFiles;
  final int deletedFiles;
  final int failedFiles;
  final String lastError;

  factory LibraryTaskStatus.fromJson(Map<String, dynamic> json) {
    return LibraryTaskStatus(
      taskType: json['task_type'] as String? ?? 'full_rescan',
      status: json['status'] as String? ?? 'idle',
      startedAt: json['started_at'] as int? ?? 0,
      finishedAt: json['finished_at'] as int? ?? 0,
      totalFiles: json['total_files'] as int? ?? 0,
      processedFiles: json['processed_files'] as int? ?? 0,
      updatedFiles: json['updated_files'] as int? ?? 0,
      skippedFiles: json['skipped_files'] as int? ?? 0,
      deletedFiles: json['deleted_files'] as int? ?? 0,
      failedFiles: json['failed_files'] as int? ?? 0,
      lastError: json['last_error'] as String? ?? '',
    );
  }

  bool get isIdle => status == 'idle';
  bool get isRunning => status == 'running';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}
