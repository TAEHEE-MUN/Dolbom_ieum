"""One-time platform configuration; does not start services or upload data."""
from pathlib import Path
import json
import plistlib
from dotenv import dotenv_values

root=Path(__file__).resolve().parents[1]
mobile=root/'apps/mobile'
manifest=mobile/'android/app/src/main/AndroidManifest.xml'
text=manifest.read_text(encoding='utf-8')
permissions='''
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
'''
if 'android.permission.ACCESS_FINE_LOCATION' not in text:
    text=text.replace('    <application',permissions+'    <application',1)
text=text.replace('android:label="dolbom_ieum"','android:label="동행이음"')
manifest.write_text(text,encoding='utf-8')
# Local cleartext is confined to DEBUG; release requires HTTPS.
debug=mobile/'android/app/src/debug/AndroidManifest.xml'
debug.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">
  <uses-permission android:name="android.permission.INTERNET"/>
  <application android:usesCleartextTraffic="true" tools:replace="android:usesCleartextTraffic"/>
</manifest>''',encoding='utf-8')
info=mobile/'ios/Runner/Info.plist'
with info.open('rb') as f: config=plistlib.load(f)
config.update({'CFBundleDisplayName':'동행이음','NSLocationWhenInUseUsageDescription':'방문 중 위치·시간 기록을 남기며 휴게·종료하면 기록을 중단합니다.',
               'NSLocationAlwaysAndWhenInUseUsageDescription':'진행 중인 방문은 화면을 잠가도 위치를 기록합니다. 휴게·종료 때 중단합니다.',
               'UIBackgroundModes':['location']})
with info.open('wb') as f: plistlib.dump(config,f,sort_keys=False)
env=dotenv_values(root/'.env')
config_dir=mobile/'config';config_dir.mkdir(exist_ok=True)
example={'API_BASE_URL':'http://YOUR_PC_LAN_IP:8000','SUPABASE_URL':'https://YOUR_PROJECT.supabase.co','SUPABASE_PUBLISHABLE_KEY':'YOUR_PUBLISHABLE_KEY'}
(config_dir/'development.example.json').write_text(json.dumps(example,indent=2),encoding='utf-8')
actual={**example,'API_BASE_URL':'http://10.0.2.2:8000','SUPABASE_URL':env['SUPABASE_URL'],'SUPABASE_PUBLISHABLE_KEY':env['SUPABASE_PUBLISHABLE_KEY']}
if not (config_dir/'development.json').exists():(config_dir/'development.json').write_text(json.dumps(actual,indent=2),encoding='utf-8')
print('Android and iOS location declarations configured. Emulator API URL: 10.0.2.2; physical phones need PC LAN IP.')
