import 'dart:io';

import 'package:bond_cli/core/native/android_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _gradleKts = '''
android {
    namespace = "ps.app.bond"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "ps.app.bond"
        minSdk = flutter.minSdkVersion
    }

    flavorDimensions += "default"
    productFlavors {
        create("production") {
            dimension = "default"
        }
        create("staging") {
            dimension = "default"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
        }
    }
}
''';

String _googleServices(String packageName) =>
    '''
{
  "client": [
    {
      "client_info": {
        "android_client_info": {
          "package_name": "$packageName"
        }
      }
    }
  ]
}
''';

String _strings(String appName) =>
    '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$appName</string>
</resources>
''';

/// src/main only defines the notification channel name; app_name lives in
/// the flavor source sets.
const _mainStrings = '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="channel">Bond</string>
</resources>''';

void main() {
  group('Gradle', () {
    test('sets applicationId and namespace in build.gradle.kts', () {
      var gradle = setGradleProperty(_gradleKts, 'applicationId', 'com.acme');
      gradle = setGradleProperty(gradle, 'namespace', 'com.acme');

      expect(gradle, contains('namespace = "com.acme"'));
      expect(gradle, contains('applicationId = "com.acme"'));
      expect(gradle, contains('applicationIdSuffix = ".staging"'));
      expect(gradle, isNot(contains('ps.app.bond')));
    });

    test('still reads and sets the Groovy syntax of older templates', () {
      const groovy = 'defaultConfig {\n  applicationId "ps.app.bond"\n}';

      expect(readGradleProperty(groovy, 'applicationId'), 'ps.app.bond');
      expect(
        setGradleProperty(groovy, 'applicationId', 'com.acme'),
        contains('applicationId "com.acme"'),
      );
    });
  });

  test('sets the app name in strings.xml, escaping XML and quotes', () {
    final xml = setStringResource(
      _strings('Bond'),
      'app_name',
      escapeAndroidString("Tom's <App> & Co"),
    );

    expect(xml, contains(r'''>Tom\'s &lt;App&gt; &amp; Co</string>'''));
  });

  test('drops the manifest package attribute of older templates', () {
    expect(
      removeManifestPackage(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"'
        '\n    package="ps.app.bond">\n</manifest>\n',
      ),
      '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
      '\n</manifest>\n',
    );
  });

  test('renames every package_name, keeping the staging suffix', () {
    expect(
      renameGoogleServicesPackages(
        _googleServices('ps.app.bond.staging'),
        'ps.app.bond',
        'com.acme.shop',
      ),
      contains('"package_name": "com.acme.shop.staging"'),
    );
  });

  group('AndroidProject', () {
    late Directory root;

    File file(String path) => File(p.joinAll([root.path, ...path.split('/')]));

    void write(String path, String content) =>
        (file(path)..createSync(recursive: true)).writeAsStringSync(content);

    setUp(() {
      root = Directory.systemTemp.createTempSync('bond_android_');
      write('android/app/build.gradle.kts', _gradleKts);
      write(
        'android/app/src/main/kotlin/ps/app/bond/MainActivity.kt',
        'package ps.app.bond\n\n'
            'import io.flutter.embedding.android.FlutterActivity\n\n'
            'class MainActivity : FlutterActivity()\n',
      );
      write(
        'android/app/src/main/AndroidManifest.xml',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
            '\n    <application android:label="@string/app_name">\n'
            '        <activity android:name=".MainActivity" />\n'
            '    </application>\n</manifest>\n',
      );
      for (final sourceSet in ['debug', 'profile']) {
        write(
          'android/app/src/$sourceSet/AndroidManifest.xml',
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
              '\n    <uses-permission android:name="android.permission.INTERNET"/>'
              '\n</manifest>\n',
        );
      }
      write(
        'android/app/src/production/google-services.json',
        _googleServices('ps.app.bond'),
      );
      write(
        'android/app/src/staging/google-services.json',
        _googleServices('ps.app.bond.staging'),
      );
      write('android/app/src/main/res/values/strings.xml', _mainStrings);
      write(
        'android/app/src/production/res/values/strings.xml',
        _strings('Bond'),
      );
      write(
        'android/app/src/staging/res/values/strings.xml',
        _strings('Bond Staging'),
      );
    });

    tearDown(() => root.deleteSync(recursive: true));

    for (final applicationId in [
      'com.acme',
      'com.acme.shop',
      'sa.co.acme.shop',
    ]) {
      test('moves MainActivity for $applicationId without reversing it', () {
        final warnings = AndroidProject(root).setApplicationId(applicationId);

        expect(warnings, isEmpty);
        final path = applicationId.replaceAll('.', '/');
        final mainActivity = file(
          'android/app/src/main/kotlin/$path/MainActivity.kt',
        );
        expect(
          mainActivity.readAsStringSync(),
          startsWith('package $applicationId\n'),
        );
        expect(file('android/app/src/main/kotlin/ps').existsSync(), isFalse);
        expect(
          file('android/app/build.gradle.kts').readAsStringSync(),
          allOf(
            contains('namespace = "$applicationId"'),
            contains('applicationId = "$applicationId"'),
          ),
        );
        expect(
          file('android/app/src/production/google-services.json')
              .readAsStringSync(),
          contains('"package_name": "$applicationId"'),
        );
        expect(
          file('android/app/src/staging/google-services.json')
              .readAsStringSync(),
          contains('"package_name": "$applicationId.staging"'),
        );
      });
    }

    for (final applicationId in ['ps.app.bond.shop', 'ps.app']) {
      test(
        'moves MainActivity into a child or parent package: $applicationId',
        () {
          AndroidProject(root).setApplicationId(applicationId);

          final path = applicationId.replaceAll('.', '/');
          final kotlin = Directory(file('android/app/src/main/kotlin').path);
          final sources = kotlin
              .listSync(recursive: true)
              .whereType<File>()
              .map((f) => p.relative(f.path, from: kotlin.path))
              .toList();
          expect(sources, [
            p.joinAll([...path.split('/'), 'MainActivity.kt']),
          ]);
          expect(
            file('android/app/src/main/kotlin/$path/MainActivity.kt')
                .readAsStringSync(),
            startsWith('package $applicationId\n'),
          );
        },
      );
    }

    test('sets the per-flavor app names', () {
      final warnings = AndroidProject(root).setAppName('Acme Shop');

      expect(warnings, isEmpty);
      expect(
        file('android/app/src/production/res/values/strings.xml')
            .readAsStringSync(),
        contains('<string name="app_name">Acme Shop</string>'),
      );
      expect(
        file('android/app/src/staging/res/values/strings.xml')
            .readAsStringSync(),
        contains('<string name="app_name">Acme Shop Staging</string>'),
      );
      expect(
        file('android/app/src/main/res/values/strings.xml').readAsStringSync(),
        _mainStrings,
      );
    });
  });
}
