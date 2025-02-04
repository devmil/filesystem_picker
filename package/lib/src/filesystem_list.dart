import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;
import 'common.dart';
import 'filesystem_list_tile.dart';
import 'options/theme/_filelist_theme.dart';
import 'progress_indicator.dart';

class FilesystemList extends StatefulWidget {
  final bool isRoot;
  final Directory rootDirectory;
  final FilesystemType fsType;
  final Color? folderIconColor;
  final List<String>? allowedExtensions;
  final ValueChanged<Directory> onChange;
  final ValueSelected onSelect;
  final FileTileSelectMode fileTileSelectMode;
  final FilesystemPickerFileListThemeData? theme;
  final bool showGoUp;
  final ScrollController? scrollController;

  FilesystemList({
    Key? key,
    this.isRoot = false,
    required this.rootDirectory,
    this.fsType = FilesystemType.all,
    this.folderIconColor,
    this.allowedExtensions,
    required this.onChange,
    required this.onSelect,
    required this.fileTileSelectMode,
    this.theme,
    this.showGoUp = true,
    this.scrollController,
  }) : super(key: key);

  @override
  State<FilesystemList> createState() => _FilesystemListState();
}

class _FilesystemListState extends State<FilesystemList> {
  late Directory rootDirectory;
  late Future<List<FileSystemEntity>> _dirContents;

  @override
  void initState() {
    super.initState();

    rootDirectory = widget.rootDirectory;
    _loadDirContents();
  }

  @override
  void didUpdateWidget(covariant FilesystemList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.rootDirectory != widget.rootDirectory) {
      rootDirectory = widget.rootDirectory;
      _loadDirContents();
    }
  }

  void _loadDirContents() async {
    var files = <FileSystemEntity>[];
    var completer = new Completer<List<FileSystemEntity>>();
    var lister = rootDirectory.list(recursive: false);
    lister.listen(
      (file) {
        if ((widget.fsType != FilesystemType.folder) || (file is Directory)) {
          if ((file is File) && (widget.allowedExtensions != null) && (widget.allowedExtensions!.length > 0)) {
            if (!widget.allowedExtensions!.contains(Path.extension(file.path))) return;
          }
          files.add(file);
        }
      },
      onDone: () {
        files.sort((a, b) => a.path.compareTo(b.path));
        completer.complete(files);
      },
    );
    _dirContents = completer.future;
  }

  InkWell _upNavigation(BuildContext context, FilesystemPickerFileListThemeData theme) {
    final iconTheme = theme.getUpIconTheme(context);

    return InkWell(
      child: ListTile(
        leading: Icon(
          theme.getUpIcon(context),
          size: iconTheme.size,
          color: iconTheme.color,
        ),
        title: Text(
          theme.getUpText(context),
          style: theme.getUpTextStyle(context),
          textScaleFactor: theme.getUpTextScaleFactor(context),
        ),
      ),
      onTap: () {
        final li = this.widget.rootDirectory.path.split(Platform.pathSeparator)..removeLast();
        widget.onChange(Directory(li.join(Platform.pathSeparator)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _dirContents,
      builder: (BuildContext context, AsyncSnapshot<List<FileSystemEntity>> snapshot) {
        final effectiveTheme = widget.theme ?? FilesystemPickerFileListThemeData();

        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text('Error loading file list: ${snapshot.error}'),
              ),
            );
          } else if (snapshot.hasData) {
            return ListView.builder(
              controller: widget.scrollController,
              shrinkWrap: true,
              itemCount: snapshot.data!.length + (widget.showGoUp ? (widget.isRoot ? 0 : 1) : 0),
              itemBuilder: (BuildContext context, int index) {
                if (widget.showGoUp && !widget.isRoot && index == 0) {
                  return _upNavigation(context, effectiveTheme);
                }

                final item = snapshot.data![index - (widget.showGoUp ? (widget.isRoot ? 0 : 1) : 0)];
                return FilesystemListTile(
                  fsType: widget.fsType,
                  item: item,
                  folderIconColor: widget.folderIconColor,
                  onChange: widget.onChange,
                  onSelect: widget.onSelect,
                  fileTileSelectMode: widget.fileTileSelectMode,
                  theme: effectiveTheme,
                );
              },
            );
          } else {
            return const SizedBox();
          }
        } else {
          return FilesystemProgressIndicator(theme: effectiveTheme);
        }
      },
    );
  }
}
