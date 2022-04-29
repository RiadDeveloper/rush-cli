import 'dart:convert';

import 'package:resolver/src/model/artifact.dart';
import 'package:resolver/src/repositories.dart';
import 'package:resolver/src/utils.dart';
import 'package:xml2json/xml2json.dart';

import 'artifact_fetcher.dart';
import 'model/maven/model.dart';
import 'model/maven/repository.dart';

class ArtifactResolver {
  late List<Repository> _repositories;
  late String _cacheDir;

  final fetcher = ArtifactFetcher();

  ArtifactResolver({
    List<Repository> repositories = Repositories.defaultRepositories,
    String? cacheDir,
  }) {
    _repositories = repositories;
    _cacheDir = cacheDir ?? Utils.defaultCacheDir;
  }

  Artifact artifactFor(String spec) {
    final parts = spec.split(':');
    if (parts.length == 3) {
      return Artifact(
          groupId: parts[0],
          artifactId: parts[1],
          version: parts[2],
          cacheDir: _cacheDir);
    } else if (parts.length == 4) {
      return Artifact(
          groupId: parts[0],
          artifactId: parts[1],
          // parts[2] is the packaging of the artifact. We extract it from pom.xml
          version: parts[3],
          cacheDir: _cacheDir);
    } else {
      throw 'Invalid artifact spec';
    }
  }

  Future<Model> resolve(Artifact artifact) async {
    final pom = await fetcher.fetchFile(artifact.pom, _repositories);
    final transformer = Xml2Json();
    transformer.parse(pom!.readAsStringSync());
    final json = transformer.toParker();
    // print(jsonDecode(json));
    final model = Model.fromJson(jsonDecode(json)['project']);
    print('Done: ${model.artifactId}');
    return model;
  }
}