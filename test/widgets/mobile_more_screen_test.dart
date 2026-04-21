import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikudrome/api/api_client.dart';
import 'package:mikudrome/models/library_task_status.dart';
import 'package:mikudrome/widgets/mobile_more_screen.dart';

void main() {
  testWidgets('MobileMoreScreen starts a rescan and shows progress', (
    tester,
  ) async {
    final client = _FakeLibraryTaskApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileMoreScreen(
            onNavigate: (_) {},
            client: client,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rescan Media Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rescan'));
    await tester.pump();

    expect(find.text('Scanning library...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('3 / 10 files'), findsOneWidget);
    expect(client.startCalls, 1);
  });

  testWidgets('MobileMoreScreen restores running task status on load', (
    tester,
  ) async {
    final client = _FakeLibraryTaskApiClient(
      initialStatus: const LibraryTaskStatus(
        taskType: 'full_rescan',
        status: 'running',
        startedAt: 1,
        finishedAt: 0,
        totalFiles: 8,
        processedFiles: 2,
        updatedFiles: 2,
        skippedFiles: 0,
        deletedFiles: 0,
        failedFiles: 0,
        lastError: '',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileMoreScreen(
            onNavigate: (_) {},
            client: client,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Scanning library...'), findsOneWidget);
    expect(find.text('2 / 8 files'), findsOneWidget);
    expect(client.statusCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('MobileMoreScreen retries after a transient status failure', (
    tester,
  ) async {
    final client = _RetryingLibraryTaskApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileMoreScreen(
            onNavigate: (_) {},
            client: client,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Scanning library...'), findsOneWidget);
    expect(client.statusCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('MobileMoreScreen does not overlap status polling requests', (
    tester,
  ) async {
    final client = _SlowStatusApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobileMoreScreen(
            onNavigate: (_) {},
            client: client,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(client.statusCalls, 1);

    client.completePending(
      const LibraryTaskStatus(
        taskType: 'full_rescan',
        status: 'idle',
        startedAt: 0,
        finishedAt: 0,
        totalFiles: 0,
        processedFiles: 0,
        updatedFiles: 0,
        skippedFiles: 0,
        deletedFiles: 0,
        failedFiles: 0,
        lastError: '',
      ),
    );
    await tester.pump();
  });
}

class _FakeLibraryTaskApiClient extends ApiClient {
  _FakeLibraryTaskApiClient({LibraryTaskStatus? initialStatus})
    : _status = initialStatus ??
          const LibraryTaskStatus(
            taskType: 'full_rescan',
            status: 'idle',
            startedAt: 0,
            finishedAt: 0,
            totalFiles: 0,
            processedFiles: 0,
            updatedFiles: 0,
            skippedFiles: 0,
            deletedFiles: 0,
            failedFiles: 0,
            lastError: '',
          ),
      super(baseUrl: 'http://example.test');

  LibraryTaskStatus _status;
  int startCalls = 0;
  int statusCalls = 0;

  @override
  Future<LibraryTaskStatus> startLibraryRescan() async {
    startCalls++;
    _status = const LibraryTaskStatus(
      taskType: 'full_rescan',
      status: 'running',
      startedAt: 1,
      finishedAt: 0,
      totalFiles: 10,
      processedFiles: 3,
      updatedFiles: 3,
      skippedFiles: 0,
      deletedFiles: 0,
      failedFiles: 0,
      lastError: '',
    );
    return _status;
  }

  @override
  Future<LibraryTaskStatus> getLibraryRescanStatus() async {
    statusCalls++;
    return _status;
  }
}

class _RetryingLibraryTaskApiClient extends _FakeLibraryTaskApiClient {
  _RetryingLibraryTaskApiClient();

  bool _shouldFailFirstStatus = true;

  @override
  Future<LibraryTaskStatus> getLibraryRescanStatus() async {
    statusCalls++;
    if (_shouldFailFirstStatus) {
      _shouldFailFirstStatus = false;
      throw ApiException('temporary failure');
    }
    return const LibraryTaskStatus(
      taskType: 'full_rescan',
      status: 'running',
      startedAt: 1,
      finishedAt: 0,
      totalFiles: 5,
      processedFiles: 2,
      updatedFiles: 2,
      skippedFiles: 0,
      deletedFiles: 0,
      failedFiles: 0,
      lastError: '',
    );
  }
}

class _SlowStatusApiClient extends _FakeLibraryTaskApiClient {
  _SlowStatusApiClient();

  Completer<LibraryTaskStatus>? _pending;

  @override
  Future<LibraryTaskStatus> getLibraryRescanStatus() {
    statusCalls++;
    _pending ??= Completer<LibraryTaskStatus>();
    return _pending!.future;
  }

  void completePending(LibraryTaskStatus status) {
    _pending?.complete(status);
    _pending = null;
  }
}
