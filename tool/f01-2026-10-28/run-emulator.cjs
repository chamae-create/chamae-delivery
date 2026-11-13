const {spawn} = require("node:child_process");
const {join} = require("node:path");
const root = join(__dirname, "..", "..");
const env = {};
// Never inherit arbitrary provider credentials or include them in Firebase CLI debug output.
for (const name of ["SystemRoot", "WINDIR", "ComSpec", "TEMP", "TMP", "USERPROFILE", "APPDATA", "LOCALAPPDATA"]) {
  if (process.env[name]) env[name] = process.env[name];
}
env.JAVA_HOME = "C:\\Program Files\\Eclipse Adoptium\\jdk-21.0.12.101-hotspot";
env.PATH = `${env.JAVA_HOME}\\bin;C:\\Program Files\\nodejs;C:\\Windows\\System32;C:\\Windows`;
env.GCLOUD_PROJECT = "demo-chamae-rules";
env.CI = "true";
env.FIREBASE_CLI_DISABLE_UPDATE_CHECK = "true";
env.XDG_CONFIG_HOME = join(__dirname, "firebase-config");
env.CLOUDSDK_CONFIG = join(__dirname, "gcloud-config");
env.NODE_OPTIONS = `--require=${join(__dirname, "loopback-only.cjs")}`;
const child = spawn(process.execPath, [
  "C:\\Users\\DELL\\AppData\\Roaming\\npm\\node_modules\\firebase-tools\\lib\\bin\\firebase.js",
  "emulators:exec", "--project", "demo-chamae-rules", "--only", "firestore,auth", "--config",
  "firebase.account-test.json", "node --test --test-concurrency=1 functions/test/customer-account.emulator.spec.js " +
  "functions/test/customer-privacy.emulator.spec.js functions/test/f01-process-restart.emulator.spec.js",
], {cwd: root, env, windowsHide: true, stdio: "inherit"});
child.on("error", () => { console.error("F01_EMULATOR_START_FAILED"); process.exitCode = 1; });
child.on("exit", (code) => { process.exitCode = code ?? 1; });
