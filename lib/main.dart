import 'dart:io';

import 'package:dynamic_layouts/dynamic_layouts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_sorter/blocs/photo_sorter_bloc/photo_sorter_bloc.dart';
import 'package:photo_sorter/utils/extensions.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Photo Sorter',
      home: _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Sorter'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            String? selectedDirectory =
                await FilePicker.platform.getDirectoryPath();

            if (selectedDirectory == null) {
              // User canceled the picker
              return;
            }
            if (context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _PreviewPage(
                    selectedDirectory: selectedDirectory,
                  ),
                ),
              );
            }
          },
          child: const Text('Select Directory'),
        ),
      ),
    );
  }
}

class _PreviewPage extends StatefulWidget {
  final String selectedDirectory;
  const _PreviewPage({super.key, required this.selectedDirectory});

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> {
  String currentSelectionMenuItem = "all";
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          PhotoSorterBloc(widget.selectedDirectory)..add(PhotoSorterStart()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Photo Sorter'),
          actions: [
            Builder(builder: (context) {
              return TextButton(
                  onPressed: () async {
                    String? selectedDirectory =
                        await FilePicker.platform.getDirectoryPath();

                    if (selectedDirectory == null) {
                      // User canceled the picker
                      return;
                    }
                    if (context.mounted) {
                      context.read<PhotoSorterBloc>().add(ExportSelected(
                            directory: Directory(selectedDirectory),
                            stringCallback: (p0) {
                              ScaffoldMessenger.maybeOf(context)
                                ?..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(content: Text(p0)));
                            },
                          ));
                    }
                  },
                  child: const Text('Export'));
            })
          ],
          bottom: AppBar(
            automaticallyImplyLeading: false,
            titleTextStyle: const TextStyle(fontSize: 12),
            title: CupertinoSegmentedControl<String>(
              children: {
                'all': const Text('All'),
              }..addAll(Map.fromEntries(FlagState.values.map((e) => MapEntry(
                  e.name,
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(e.name.capitalize())))))),
              onValueChanged: (value) {
                setState(() {
                  currentSelectionMenuItem = value;
                });
              },
              groupValue: currentSelectionMenuItem,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<PhotoSorterBloc, PhotoSorterState>(
                  builder: (context, state) {
                switch (state) {
                  case PhotoSorterUninitialized():
                    return _Loading();
                  case PhotoSorterUnsortedFilesScanned():
                    return _PhotoSorterGrid(
                      items: currentSelectionMenuItem == "all"
                          ? Map.fromEntries(state.fileList.entries)
                          : Map.fromEntries(
                              state.fileList.entries.where((element) =>
                                  element.value.name ==
                                  currentSelectionMenuItem),
                            ),
                      orientations: state.fileOrientations,
                    );
                  case PhotoSortedError():
                    return _Error();
                }
              }),
            ),
            BlocBuilder<PhotoSorterBloc, PhotoSorterState>(
                builder: (context, state) {
              switch (state) {
                case PhotoSorterUninitialized():
                  return const SizedBox.shrink();
                case PhotoSorterUnsortedFilesScanned():
                  return Text(state.fileList.entries.fold(
                      <String, int>{},
                      (previousValue, element) => previousValue
                        ..update(element.value.name.capitalize(),
                            (value) => value + 1,
                            ifAbsent: () => 1)).toString());
                case PhotoSortedError():
                  return const SizedBox.shrink();
              }
            }),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator.adaptive(),
    );
  }
}

class _Error extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Error'),
    );
  }
}

class _PhotoSorterGrid extends StatelessWidget {
  final Map<File, FlagState> items;
  final Map<File, Orientation> orientations;

  const _PhotoSorterGrid(
      {super.key, required this.items, required this.orientations});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PhotoSorterBloc>();
    final entries = items.entries.toList();
    itemBuilder(context, index) {
      final item = entries[index];
      final orientation = orientations[item.key];

      final double aspectRatio;
      if (orientation == Orientation.landscape) {
        aspectRatio = 4 / 3;
      } else {
        aspectRatio = 3 / 4;
      }
      return AspectRatio(
        key: ValueKey(item.key),
        aspectRatio: aspectRatio,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          color: switch (item.value) {
            FlagState.selected => Colors.green.shade100,
            FlagState.unflagged => null,
            FlagState.rejected => Colors.red.shade100,
          },
          elevation: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) {
                      return BlocProvider.value(
                        value: bloc,
                        child: _PhotoPreview(file: item.key),
                      );
                    }));
                  },
                  child: SizedBox.expand(
                    child: Image.file(
                      item.key,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      bloc.add(
                        PhotoSorterChangeFragEvent(
                            FlagState.selected, item.key),
                      );
                    },
                    icon: const Icon(
                      Icons.flag_outlined,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  IconButton(
                    onPressed: () {
                      bloc.add(
                        PhotoSorterChangeFragEvent(
                            FlagState.unflagged, item.key),
                      );
                    },
                    icon: const Icon(
                      Icons.flag_outlined,
                      //                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  IconButton(
                    onPressed: () {
                      bloc.add(
                        PhotoSorterChangeFragEvent(
                            FlagState.rejected, item.key),
                      );
                    },
                    icon: Icon(
                      Icons.flag_outlined,
                      color: Colors.red.shade300,
                      size: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      );
    }

    return DynamicGridView.staggered(
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      crossAxisCount: 3,
      children: Iterable.generate(
          entries.length, (index) => itemBuilder(context, index)).toList(),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  final File file;

  const _PhotoPreview({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Sorter'),
      ),
      body: InteractiveViewer(
        child: Center(
          child: Card(
            child: Image.file(file),
          ),
        ),
      ),
    );
  }
}
