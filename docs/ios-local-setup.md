# Peekaboo iOS local setup

This repo now includes a Flutter iOS project under `ios/`.

Use these steps on your Mac with Xcode installed.

## 1. Install/verify tools

```bash
flutter doctor -v
xcodebuild -version
```

If Flutter reports missing iOS setup, follow its prompts, usually:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods
```

## 2. Clone/pull the repo

```bash
git clone <YOUR_GITHUB_REPO_URL> peekaboo_mvp
cd peekaboo_mvp
```

If you already cloned it:

```bash
cd peekaboo_mvp
git pull
```

## 3. Create local environment file

Create `.env` from `.env.example`:

```bash
cp .env.example .env
```

Fill in:

```text
SUPABASE_PROJECT_REF=dckscvcafelyblkvbefv
SUPABASE_URL=https://dckscvcafelyblkvbefv.supabase.co
SUPABASE_ANON_KEY=<public anon key from Supabase dashboard>
AUTH_MODE=email
WHISPER_PROVIDER=openai
```

Do not commit `.env`; it is gitignored.

## 4. Install Flutter packages

```bash
flutter pub get
```

## 5. Open iOS project in Xcode

```bash
open ios/Runner.xcworkspace
```

In Xcode:

1. Select `Runner` project.
2. Select `Runner` target.
3. Go to `Signing & Capabilities`.
4. Choose your Apple developer team.
5. Keep bundle identifier as:

```text
com.peekaboo.mvp
```

If your team already has that bundle ID taken, change it to something unique, for example:

```text
com.yourcompany.peekaboo
```

## 6. Run on your iPhone

Connect your iPhone by cable, unlock it, trust the Mac, then run:

```bash
flutter run -d ios \
  --dart-define=SUPABASE_URL=https://dckscvcafelyblkvbefv.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<public anon key from Supabase dashboard>
```

Or choose your iPhone in Xcode and press Run.

## 7. Build an iOS release later

A real App Store/TestFlight build must be done on macOS:

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://dckscvcafelyblkvbefv.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<public anon key from Supabase dashboard>
```

Then upload with Xcode Organizer or Transporter.

## Notes

- The Linux agent cannot compile iOS apps because Apple requires macOS + Xcode.
- The iOS project is prepared and committed here; your Mac will do the final iOS build/signing.
- Microphone permission has been added for read-aloud pronunciation feedback.
- Supabase backend is already deployed to the Peekaboo Supabase project.
