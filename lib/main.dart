import 'dart:convert';
import 'dart:html'; // ignore: avoid_web_libraries_in_flutter

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'package:http_requests/http_requests.dart';
import 'package:cyberflix_web/catalog_Item.dart';
import 'package:reorderables/reorderables.dart';

void main() {
  runApp(const MyApp());
}

enum ConfigStage { stage0, stage1, stage2, stage3 }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyberFlix Configuration',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(),
        useMaterial3: true,
      ),
      home: const Home(title: 'CyberFlix Configuration'),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key, required this.title});

  final String title;

  @override
  State<Home> createState() => _HomeState();
}

class ErrorAlertDialog extends StatelessWidget {
  final String errorMessage;

  const ErrorAlertDialog({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Error'),
      content: Text(errorMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _HomeState extends State<Home> {
  bool isInstalling = false;
  ConfigStage currentStage = ConfigStage.stage0;

  // String baseUrl = "https://82d7ae415a21-llama-catalog.baby-beamup.club/";
  // String baseUrl = "http://127.0.0.1:8000/";
  String baseUrl = '${window.location.origin}/';
  List<CatalogItem> baseCatalog = [];
  List<CatalogItem> validData = [];
  int catalogLimit = 0;
  bool enableTrakt = false;
  bool enableRPDB = false;
  bool enableLang = false;
  String rpdbApikey = "";
  String traktCode = "";
  Map<String, String> catalogLanguages = {"English": "en"};
  String selectedCatalogLanguage = 'en';
  String intro =
      'Welcome to the Cyberflix Configuration Wizard! This user-friendly tool is designed to assist you in customizing the Cyberflix catalog according to your preferences.';
  String sponsor = "";

  Future<Map> _loadData() async {
    try {
      String url = "${baseUrl}web_config.json";
      HttpResponse response = await HttpRequests.get(url);
      if (response.statusCode != 200) {
        throw Exception('Failed to load data');
      }
      return json.decode(response.content);
    } catch (e) {
      // ignore: avoid_print
      //print(e.toString());
      return {};
    }
  }

  Future<String> _regixConfig(String config) async {
    String url = "${baseUrl}regix_config";

    Map<String, String> data = {'config': config};
    HttpResponse response = await HttpRequests.post(url, data: data);

    if (response.statusCode != 200) {
      throw Exception('Failed to load data');
    }
    try {
      return json.decode(response.content)['id'];
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<String> _getTrakitLink() async {
    String url = "${baseUrl}get_trakt_url";
    HttpResponse response = await HttpRequests.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to load data');
    }
    try {
      return json.decode(response.content)['url'];
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<String> _getTrakitToken(String code) async {
    String url = "${baseUrl}get_trakt_access_token";

    Map<String, String> data = {'code': code};
    HttpResponse response = await HttpRequests.post(url, data: data);

    if (response.statusCode != 200) {
      throw Exception('Failed to load data');
    }
    try {
      return json.decode(response.content)['access_token'];
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData().then((value) => {
          setState(() {
            final config = value['config'];
            catalogLimit = config['max_num_of_catalogs'];
            enableLang = config['enable_lang'];
            enableRPDB = config['enable_rpdb'];
            enableTrakt = config['enable_trackt'];
            sponsor = config['sponsor'];
            final List<String> selectedCatalogs =
                List.from(config['default_catalogs']);
            selectedCatalogLanguage = config['default_language'];
            catalogLanguages = Map.from(config['languages']);

            final catalogConfig = List.from(config['catalogs']);
            for (int i = 0; i < catalogConfig.length; i++) {
              baseCatalog.add(CatalogItem.fromJson(catalogConfig[i]));
            }
            if (enableTrakt == false) {
              baseCatalog.removeWhere((element) => element.uuid == "69c5c");
            }
            baseCatalog = updateSelectedDataById(baseCatalog, selectedCatalogs);
            updateData();
            validData = updatedSelectedData(baseCatalog);
          })
        });
  }

  Future<List<String>> getStremioLink() async {
    var configList = validData.map((e) => e.uuid).toList();
    final configString = configList
        .toString()
        .replaceFirst("[", "")
        .replaceFirst("]", "")
        .replaceAll(" ", "");

    final regixId = await _regixConfig(configString);
    var traktToken = "";
    if (traktCode != "") {
      traktToken = await _getTrakitToken(traktCode);
    }

    List<List<String>> configurationValue = [
      ["catalogs", regixId],
      if (rpdbApikey != "") ["rpgb", rpdbApikey],
      if (traktToken != "") ["trakt", traktToken],
      ["lang", selectedCatalogLanguage]
    ];
    //E2397DBB
    var filterConfig = configurationValue
        .where((entry) => entry[1].isNotEmpty)
        .map((entry) => "${entry[0]}=${entry[1]}")
        .toList();

    String configuration =
        filterConfig.isNotEmpty ? filterConfig.join("|") : "";

    String config = "c/$configuration/manifest.json";
    String httpLink = "$baseUrl$config";

    // window.history.pushState(null, "Manifiest", config);
    final stremioLink =
        "stremio://${httpLink.replaceAll('https://', '').replaceAll('http://', '')}";
    return [httpLink, stremioLink];
  }

  String getFullLabel(List<CatalogItem> data, String uuid) {
    for (int i = 0; i < data.length; i++) {
      if (data[i].uuid == uuid) {
        return data[i].name;
      } else {
        var newData = getFullLabel(data[i].children, uuid);
        if (newData.isNotEmpty) {
          return "${data[i].name} > $newData";
        }
      }
    }
    return "";
  }

  List<CatalogItem> updateSelectedDataById(
      List<CatalogItem> data, List<String> ids) {
    for (int i = 0; i < data.length; i++) {
      data[i].children = updateSelectedDataById(data[i].children, ids);
      data[i].isSelected = ids.contains(data[i].uuid);
    }
    return data;
  }

  bool isIdsSelected(List<CatalogItem> data, List<String> ids) {
    for (int i = 0; i < data.length; i++) {
      if (data[i].children.isEmpty && ids.contains(data[i].uuid)) {
        return true;
      } else {
        var isSelected = isIdsSelected(data[i].children, ids);
        if (isSelected) {
          return true;
        }
      }
    }
    return false;
  }

  int countSelectedData(List<CatalogItem> data) {
    int count = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i].children.isEmpty && data[i].isSelected) {
        count += 1;
      } else {
        var counts = countSelectedData(data[i].children);
        count += counts;
      }
    }
    return count;
  }

  List<CatalogItem> updatedSelectedData(List<CatalogItem> data) {
    List<CatalogItem> selectedData = [];
    for (int i = 0; i < data.length; i++) {
      if (data[i].children.isEmpty && data[i].isSelected) {
        selectedData.add(data[i]);
      } else {
        var newData = updatedSelectedData(data[i].children);
        selectedData.addAll(newData);
      }
    }
    return selectedData;
  }

  void updateData() {
    for (int i = 0; i < baseCatalog.length; i++) {
      updateChildern(baseCatalog[i].children, baseCatalog[i].isSelected);
    }
  }

  void updateChildern(List<CatalogItem> children, bool value) {
    for (int i = 0; i < children.length; i++) {
      var totalSelected = countSelectedData(baseCatalog);
      final selectedValue = value && totalSelected < catalogLimit;
      children[i].isSelected = selectedValue;
      updateChildern(children[i].children, selectedValue);
    }
  }

  Widget stageZero() {
    return Column(
      children: [
        if (sponsor.isNotEmpty) HtmlWidget(sponsor),
        if (sponsor.isEmpty)
          Text(
            intro,
            style: const TextStyle(fontSize: 20),
          ),
        const SizedBox(height: 40),
        Row(
          children: [
            const Spacer(),
            ButtonTheme(
              minWidth: 200,
              height: 100,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 3,
                  padding: const EdgeInsets.all(25),
                ),
                onPressed: () {
                  setState(() {
                    currentStage = ConfigStage.stage1;
                  });
                },
                child: const Text(
                  'Setup',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            const Spacer(),
          ],
        )
      ],
    );
  }

  Widget stageOne() {
    return Column(
      children: [
        Text(
          validData.isEmpty || catalogLimit == 0
              ? "Select the catalogs you want to include"
              : "Selelected catalogs: ${validData.length}/$catalogLimit",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 30),
        ),
        Text(
          validData.isEmpty || catalogLimit == 0
              ? 'Simply choose the desired catalogs by ticking the checkboxes next to them.'
              : 'This softcap is to ensure that the addon will be sync to stremio servers.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 40),
        if (baseCatalog.isNotEmpty)
          SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(25.0),
              ),
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
              child: Column(
                children: [
                  for (int i = 0; i < baseCatalog.length; i++)
                    getTiles(baseCatalog, i)
                ],
              ),
            ),
          ),
        const SizedBox(height: 40),
        Row(
          children: [
            const Spacer(),
            ButtonTheme(
              minWidth: 200,
              height: 100,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 3,
                  padding: const EdgeInsets.all(25),
                ),
                onPressed: validData.isEmpty
                    ? null
                    : () {
                        setState(() {
                          currentStage = ConfigStage.stage2;
                        });
                      },
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            const Spacer(),
          ],
        )
      ],
    );
  }

  Widget stageTwo() {
    return Column(
      children: [
        const Text(
          'Arrange catalogs to customize your Stremio experience',
          style: TextStyle(fontSize: 30),
        ),
        const SizedBox(height: 40),
        ReorderableWrap(
          spacing: 8.0,
          runSpacing: 4.0,
          needsLongPressDraggable: false,
          padding: const EdgeInsets.all(8),
          children: [
            for (int i = 0; i < validData.length; i++)
              Chip(
                label: Text(
                    "(${i + 1}) ${getFullLabel(baseCatalog, validData[i].uuid)}"),
              ),
          ],
          onReorder: (oldIndex, newIndex) => {
            setState(() {
              validData.insert(newIndex, validData.removeAt(oldIndex));
            }),
          },
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            const Spacer(),
            ButtonTheme(
              minWidth: 200,
              height: 100,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 3,
                  padding: const EdgeInsets.all(25),
                ),
                onPressed: () {
                  setState(() {
                    currentStage = ConfigStage.stage3;
                  });
                },
                child: const Text(
                  'Next',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
            const Spacer(),
          ],
        )
      ],
    );
  }

  Widget stageTree() {
    return Column(
      children: [
        const Text(
          'Configuration almost complete!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30),
        ),
        const SizedBox(height: 40),
        if (enableLang)
          Column(
            children: [
              const Text('Select the language for the catalogs',
                  style: TextStyle(fontSize: 24)),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedCatalogLanguage,
                icon: const Icon(Icons.arrow_downward),
                iconSize: 24,
                elevation: 16,
                style: const TextStyle(color: Colors.white),
                underline: Container(
                  height: 2,
                  color: Colors.white,
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedCatalogLanguage = newValue ?? "en";
                  });
                },
                items: catalogLanguages.keys
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: catalogLanguages[value],
                    child: Text(value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        if (isIdsSelected(validData, ['35859', 'df64e']) && enableTrakt)
          Column(
            children: [
              const Text('Recommendations Catalog requires a Trakt code',
                  style: TextStyle(fontSize: 24)),
              const SizedBox(height: 10),
              TextField(
                  obscureText: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Trakt Code(Required)',
                  ),
                  onChanged: (value) {
                    traktCode = value;
                  },
                  autocorrect: false),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.left,
                text: TextSpan(
                  children: <TextSpan>[
                    const TextSpan(
                        text: 'To get you Trakt Code click ',
                        style: TextStyle(color: Colors.white)),
                    TextSpan(
                        text: 'here',
                        style: const TextStyle(color: Colors.blue),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            await _getTrakitLink().then((value) {
                              js.context.callMethod('open', [value]);
                            });
                          }),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        if (enableRPDB)
          Column(
            children: [
              const Text('For posters alongside ratings, use your RPDB key',
                  style: TextStyle(fontSize: 24)),
              const SizedBox(height: 10),
              TextField(
                  obscureText: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'RPDB API Key(Optional)',
                  ),
                  onChanged: (value) {
                    rpdbApikey = value;
                  },
                  autocorrect: false),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.left,
                text: TextSpan(
                  children: <TextSpan>[
                    const TextSpan(
                        text: 'To get you RPDB Key click ',
                        style: TextStyle(color: Colors.white)),
                    TextSpan(
                        text: 'here',
                        style: const TextStyle(color: Colors.blue),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            const url = "https://ratingposterdb.com/api-key";
                            js.context.callMethod('open', [url]);
                          }),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        Row(
          children: [
            const Spacer(),
            Column(
              children: [
                ButtonTheme(
                  minWidth: 200,
                  height: 100,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 3,
                      padding: const EdgeInsets.all(25),
                    ),
                    onPressed: isInstalling
                        ? null
                        : () {
                            setState(() async {
                              final isRecommendedSelected =
                                  isIdsSelected(validData, ['35859', 'df64e']);
                              if (isRecommendedSelected && traktCode == "") {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return const ErrorAlertDialog(
                                        errorMessage:
                                            "Trakt Code is required!\nPlease enter your Trakt Code to install the addon.");
                                  },
                                );
                              } else {
                                isInstalling = true;
                                await getStremioLink().then((value) => {
                                      isInstalling = false,
                                      js.context.callMethod('open', [value[1]])
                                    });
                              }
                            });
                          },
                    icon: isInstalling
                        ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.0),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(Icons.install_desktop),
                    label: const Text(
                      'Install on Stremio',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () async {
                    final links = await getStremioLink();
                    await Clipboard.setData(ClipboardData(text: links[0]));
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Link copied to clipboard!"),
                    ));
                  },
                  child: const Text('or click to copy to clipboard'),
                ),
              ],
            ),
            const Spacer(),
          ],
        )
      ],
    );
  }

  Widget getTiles(List<CatalogItem> data, int id) {
    return data[id].children.isNotEmpty
        ? ExpansionTile(
            title: Text(data[id].name),
            leading: Checkbox(
                value: data[id].isSelected,
                onChanged: (value) {
                  setState(() {
                    var isSelected = value ?? false;
                    var totalSelected = countSelectedData(baseCatalog);
                    if (totalSelected >= catalogLimit) {
                      isSelected = false;
                    }
                    data[id].isSelected = isSelected;
                    updateChildern(data[id].children, isSelected);
                    validData = updatedSelectedData(baseCatalog);
                  });
                }),
            children: [
              for (int i = 0; i < data[id].children.length; i++)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 4, 4, 4),
                  child: getTiles(data[id].children, i),
                )
            ],
          )
        : Container(
            padding: const EdgeInsets.fromLTRB(24, 4, 4, 4),
            child: Row(
              children: [
                Checkbox(
                  value: data[id].isSelected,
                  onChanged: (value) {
                    setState(() {
                      var isSelected = value ?? false;
                      var totalSelected = countSelectedData(baseCatalog);
                      if (totalSelected >= catalogLimit) {
                        isSelected = false;
                      }
                      data[id].isSelected = isSelected;
                      updateChildern(data[id].children, isSelected);
                      validData = updatedSelectedData(baseCatalog);
                    });
                  },
                ),
                const SizedBox(width: 12),
                Text(
                  data[id].name,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg_image.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black, Colors.transparent],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 50, 0, 50),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 600,
                      maxWidth: 600,
                    ),
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(25.0),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (currentStage != ConfigStage.stage0)
                              IconButton(
                                style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.all(
                                        Colors.black26),
                                    foregroundColor: MaterialStateProperty.all(
                                        Colors.white)),
                                iconSize: 24,
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () {
                                  setState(() {
                                    currentStage = ConfigStage
                                        .values[currentStage.index - 1];
                                  });
                                },
                              ),
                            const Spacer(),
                            IconButton(
                              iconSize: 24,
                              style: ButtonStyle(
                                  backgroundColor:
                                      MaterialStateProperty.all(Colors.black26),
                                  foregroundColor:
                                      MaterialStateProperty.all(Colors.white)),
                              icon: const Icon(Icons.question_mark),
                              onPressed: () {
                                js.context.callMethod('open', [
                                  'https://stremio-addons.netlify.app/cyberflix-catalog.html'
                                ]);
                              },
                            ),
                          ],
                        ),
                        if (currentStage == ConfigStage.stage0)
                          const Column(
                            children: [
                              Text(
                                "CYBERFLIX",
                                style: TextStyle(
                                  fontSize: 45,
                                ),
                              ),
                              SizedBox(height: 20),
                              CircleAvatar(
                                radius: 64, // Image radius
                                backgroundImage: AssetImage('assets/logo.png'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 40),
                        if (currentStage == ConfigStage.stage0) stageZero(),
                        if (currentStage == ConfigStage.stage1) stageOne(),
                        if (currentStage == ConfigStage.stage2) stageTwo(),
                        if (currentStage == ConfigStage.stage3) stageTree(),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ButtonStyle(
                                  backgroundColor:
                                      MaterialStateProperty.all(Colors.black26),
                                  foregroundColor:
                                      MaterialStateProperty.all(Colors.white)),
                              icon: Image.asset('assets/kofi.png'),
                              label: const Text('Support me on Ko-fi'),
                              onPressed: () {
                                js.context.callMethod(
                                    'open', ['https://ko-fi.com/marcojoao']);
                              },
                            ),
                            const Spacer()
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
