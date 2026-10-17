from pathlib import Path
import argparse,tempfile
parser=argparse.ArgumentParser()
parser.add_argument('--device',required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
work=Path(tempfile.mkdtemp(prefix='sheet-pan-gate-tests-'))
import plistlib,subprocess
p=work/'SheetInspect.app';p.mkdir(exist_ok=True)
sdk=subprocess.check_output(['xcrun','--sdk','iphonesimulator','--show-sdk-path'],text=True).strip()
subprocess.run(['xcrun','clang','-fno-objc-arc','-isysroot',sdk,'-target','arm64-apple-ios18.0-simulator','-c',str(root/'ios/Classes/TiSheetPanGate.m'),'-o',str(work/'TiSheetPanGate.o')],check=True)
subprocess.run(['xcrun','clang','-I',str(root/'ios/Classes'),str(work/'TiSheetPanGate.o'),'-fobjc-arc','-isysroot',sdk,'-target','arm64-apple-ios18.0-simulator','-framework','UIKit','-framework','Foundation','-framework','QuartzCore',str(root/'tests/sheet-pan-gate.m'),'-o',str(p/'SheetInspect')],check=True)
(p/'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable':'SheetInspect','CFBundleIdentifier':'com.designbymind.sheetinspect','CFBundleName':'SheetInspect','CFBundlePackageType':'APPL','CFBundleVersion':'1','MinimumOSVersion':'18.0','UIApplicationSceneManifest':{'UISceneConfigurations':{'UIWindowSceneSessionRoleApplication':[{'UISceneConfigurationName':'Default','UISceneDelegateClassName':'Scene'}]}}}))
subprocess.run(['codesign','--force','--sign','-',str(p)],check=True)
subprocess.run(['xcrun','simctl','install',args.device,str(p)],check=True)
subprocess.run(['xcrun','simctl','launch','--terminate-running-process','--console',args.device,'com.designbymind.sheetinspect'],check=True,timeout=30)
