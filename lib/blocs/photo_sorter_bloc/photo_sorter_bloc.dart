import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_sorter/utils/extensions.dart';

class PhotoSorterBloc extends Bloc<PhotoSorterEvent, PhotoSorterState> {
  final String _directory;
  PhotoSorterBloc(this._directory) : super(PhotoSorterUninitialized()) {
    on<PhotoSorterStart>(
      (event, emit) async {
        final cacheFile = await _getCacheFile();
        Map<String, dynamic> jsonMap = {};
        if (await cacheFile.exists()) {
          String content = await cacheFile.readAsString();
          jsonMap = jsonDecode(content);
        }

        Directory rootDirectory = Directory(_directory);
        Map<File, FlagState> files = {};
        Map<File, Orientation> fileOrientation = {};

        Completer<void> completer = Completer();

        rootDirectory.list(recursive: true).listen((event) async {
          if (event is File &&
              kDefaultContentInsertionMimeTypes.contains(MimeTypeResolver()
                  .lookup(event.path)
                  ?.toString()
                  .toLowerCase())) {
            final flag = jsonMap[event.absolute.path].toString();
            files[event] = switch (flag) {
              String() => FlagState.values.firstWhere(
                  (element) => element.name == flag,
                  orElse: () => FlagState.unflagged),
            };
          }
        }, onDone: () {
          completer.complete();
        }, onError: (_) {
          emit(PhotoSortedError());
          completer.complete();
        });

        await completer.future;

        for (var file in files.keys) {
          final data = await compute(
            _getOrientation,
            file,
          );

          fileOrientation[file] = data == Orientation.landscape.name
              ? Orientation.landscape
              : Orientation.portrait;
          emit(PhotoSorterUnsortedFilesScanned(
              fileList: Map.of(files),
              fileOrientations: Map.of(fileOrientation)));
        }
      },
    );
    on<PhotoSorterChangeFragEvent>((event, emit) async {
      final currentState = state;
      switch (currentState) {
        case PhotoSorterUnsortedFilesScanned():
          final fileList = Map.of(currentState.fileList)
            ..update(event.file, (value) => event.flagState);

          final json = jsonEncode(fileList.map(
            (key, value) => MapEntry(key.absolute.path, value.name),
          ));

          await _getCacheFile().then(
            (value) {
              value.writeAsString(json, mode: FileMode.writeOnly);
            },
          );

          emit(PhotoSorterUnsortedFilesScanned(
              fileList: fileList,
              fileOrientations: currentState.fileOrientations));
        case _:
          return;
      }
    });

    on<ExportSelected>((event, emit) async {
      final currentState = state;
      if (currentState is PhotoSorterUnsortedFilesScanned) {
        final selectedFile = currentState.fileList.entries
            .where((element) => element.value == FlagState.selected)
            .map((e) => e.key)
            .toList();
        for (int i = 0; i < selectedFile.length; i++) {
          var element = selectedFile[i];
          final targetFile = File(event.directory.absolute.path +
              Platform.pathSeparator +
              element.uri.pathSegments.last);
          await element.copy(targetFile.absolute.path);
          event.stringCallback
              ?.call("${i + 1} / ${selectedFile.length} copied");
        }
      }
    });
  }

  static String _getOrientation(File file) {
    final size = ImageSizeGetter.getSize(FileInput(file));
    if (size.needRotate) {
      return Orientation.portrait.name;
    } else {
      return Orientation.landscape.name;
    }
  }

  Future<File> _getCacheFile() async {
    final Directory appDocumentDirectory = await getApplicationCacheDirectory();
    final cacheFile = File(
        "${appDocumentDirectory.absolute.path}${Platform.pathSeparator}cache.json");
    return cacheFile;
  }
}

@immutable
sealed class PhotoSorterEvent extends Equatable with DefaultOverrides {}

class PhotoSorterStart extends PhotoSorterEvent {}

class PhotoSorterChangeFragEvent extends PhotoSorterEvent {
  final FlagState flagState;
  final File file;

  PhotoSorterChangeFragEvent(this.flagState, this.file);
}

class ExportSelected extends PhotoSorterEvent {
  final Directory directory;
  final Function(String)? stringCallback;

  ExportSelected({required this.directory, this.stringCallback});
}

@immutable
sealed class PhotoSorterState extends Equatable with DefaultOverrides {}

class PhotoSorterUninitialized extends PhotoSorterState {}

class PhotoSorterUnsortedFilesScanned extends PhotoSorterState {
  final Map<File, FlagState> fileList;
  final Map<File, Orientation> fileOrientations;
  final bool isLoading;

  PhotoSorterUnsortedFilesScanned({
    required this.fileList,
    required this.fileOrientations,
    this.isLoading = true,
  });

  @override
  List<Object?> get props => [fileList, fileOrientations, isLoading];
}

class PhotoSortedError extends PhotoSorterState {}

enum FlagState { selected, rejected, unflagged }
