# 🚀 DEPLOYMENT GUIDE - WATERWISE MOBILE

**How to build and deploy the fixed APK**

---

## 📦 BUILDING THE APK

### Step 1: Open Godot Export Settings

1. Open your project in **Godot Editor**
2. Go to: **Project → Export**
3. Select **Android** export preset (or create one if it doesn't exist)

### Step 2: Configure Export Settings

Make sure these settings are correct:

```
Export Settings:
├── Export Path: waterwise_v1.1_fixed.apk
├── Export Mode: Release (for production) or Debug (for testing)
├── Min SDK: 21 (Android 5.0)
├── Target SDK: 33 (Android 13)
└── Permissions:
    ├── INTERNET ✅ (for multiplayer)
    ├── ACCESS_NETWORK_STATE ✅ (for multiplayer)
    ├── ACCESS_WIFI_STATE ✅ (for multiplayer)
    └── WRITE_EXTERNAL_STORAGE ❌ (not needed, using internal storage)
```

### Step 3: Export the APK

1. Click **Export Project** button
2. Choose save location (e.g., `builds/waterwise_v1.1_fixed.apk`)
3. Wait for export to complete (30-60 seconds)
4. APK file is ready!

---

## 📱 INSTALLING ON DEVICES

### Method 1: Direct USB Transfer (Fastest)

1. Connect Android device to computer via USB
2. Enable **File Transfer** mode on device
3. Copy APK to device's **Downloads** folder
4. On device: Open **Files** app → **Downloads**
5. Tap the APK file
6. Tap **Install** (allow "Install from unknown sources" if prompted)
7. Done!

### Method 2: Cloud Transfer (No Cable Needed)

1. Upload APK to **Google Drive** / **Dropbox** / **OneDrive**
2. On device: Open cloud app
3. Download the APK
4. Tap the downloaded APK
5. Tap **Install**
6. Done!

### Method 3: Email Transfer

1. Email the APK to yourself
2. On device: Open email
3. Download attachment
4. Tap the APK file
5. Tap **Install**
6. Done!

### Method 4: QR Code (For Multiple Devices)

1. Upload APK to a file hosting service
2. Generate QR code for download link
3. Scan QR code on each device
4. Download and install
5. Done!

---

## 🔧 ENABLING "INSTALL FROM UNKNOWN SOURCES"

If you see a security warning when installing:

### Android 8.0+ (Oreo and newer):
1. When prompted, tap **Settings**
2. Enable **Allow from this source**
3. Go back and tap **Install**

### Android 7.1 and older:
1. Go to **Settings → Security**
2. Enable **Unknown sources**
3. Go back and install APK

**Note:** This is normal for apps not from Google Play Store. Your app is safe!

---

## 🧪 TESTING WORKFLOW

### For 2-Device Multiplayer Testing:

```
Device 1 (Host):
1. Install APK
2. Open game
3. Go to Multiplayer
4. Create hotspot on device
5. Host game

Device 2 (Client):
1. Install APK
2. Connect to Device 1's hotspot
3. Open game
4. Go to Multiplayer
5. Join game

Test:
- Play until quota reached
- Verify game ends properly
- Check for freezing
- Monitor FPS
```

### For Single-Player Testing:

```
1. Install APK
2. Open game
3. Play 5 games in a row
4. Check for:
   - Blue screen after game 2
   - Frame drops during cutscenes
   - Lag during transitions
   - Touch input responsiveness
   - Memory usage
```

---

## 🐛 DEBUGGING (OPTIONAL)

### Viewing Logs via ADB (For Developers):

If you need to see console logs for debugging:

```bash
# 1. Enable USB Debugging on device:
Settings → About Phone → Tap "Build Number" 7 times
Settings → Developer Options → Enable "USB Debugging"

# 2. Connect device via USB

# 3. View logs:
adb logcat | grep "Godot\|WaterWise"

# 4. View specific errors:
adb logcat | grep "ERROR\|WARN"

# 5. Save logs to file:
adb logcat > game_log.txt
```

### Accessing Saved Files (For Developers):

```bash
# Pull all game files from device:
adb pull /data/data/com.waterwise.thesis/files/ ./exported_files/

# View specific file:
adb shell cat /data/data/com.waterwise.thesis/files/waterwise_save.json
```

**Note:** ADB is only for debugging. Normal users don't need this!

---

## 📊 PERFORMANCE MONITORING

### Built-in FPS Counter (If Available):

```
In-game: Enable FPS counter in settings
Watch for:
- Gameplay: Should be 55-60 FPS
- Cutscenes: Should be 50-60 FPS
- Transitions: Should be smooth
```

### Memory Monitoring via ADB:

```bash
# Check memory usage:
adb shell dumpsys meminfo com.waterwise.thesis

# Look for:
Total PSS: Should be <250 MB
```

### Battery Monitoring:

```
Play for 30 minutes
Check battery usage in Settings → Battery
Should use <10% battery per 30 minutes
```

---

## ✅ DEPLOYMENT CHECKLIST

### Pre-Deployment:
- [x] All fixes applied to code
- [ ] APK built successfully
- [ ] APK tested on 1 device (smoke test)
- [ ] APK tested on 2 devices (multiplayer)
- [ ] No crashes during 30-min session
- [ ] Performance meets targets (60 FPS)

### Production Deployment:
- [ ] Version number updated
- [ ] Release notes written
- [ ] APK signed with release key
- [ ] APK uploaded to distribution platform
- [ ] Users notified of update

---

## 🎯 QUICK TESTING CHECKLIST

Use this for rapid testing:

```
✅ Multiplayer Test (2 min):
   - Host + Join game
   - Play until quota
   - Game ends properly
   - No freezing

✅ Blue Screen Test (1 min):
   - Play 3 games in a row
   - No blue screen
   - Smooth transitions

✅ Performance Test (1 min):
   - Play 1 game
   - Watch cutscene
   - Check FPS (should be 55-60)

✅ Touch Test (1 min):
   - Tap 10 objects
   - All taps register
   - Visual feedback appears

✅ Memory Test (5 min):
   - Play 10 games
   - Check memory usage
   - Should stay <250MB
```

---

## 🚨 COMMON ISSUES

### Issue: "App not installed"
**Solution:** 
- Uninstall old version first
- Check device has enough storage (need 200MB+)
- Try different installation method

### Issue: "Parse error"
**Solution:**
- APK file corrupted during transfer
- Re-export from Godot
- Try different transfer method

### Issue: App crashes on launch
**Solution:**
- Check Android version (need 5.0+)
- Check device has 2GB+ RAM
- View logs with ADB to see error

### Issue: Multiplayer can't connect
**Solution:**
- Both devices on same WiFi/hotspot
- Check firewall settings
- Try different network

---

## 📞 SUPPORT

### If Testing Fails:

**Multiplayer Issues:**
- Check both devices have same APK version
- Verify network connection
- Test with different devices
- View logs: `adb logcat | grep "Multiplayer"`

**Performance Issues:**
- Check device specs (need 2GB+ RAM)
- Close background apps
- Test on different device
- View logs: `adb logcat | grep "FPS\|Performance"`

**Crash Issues:**
- View crash logs: `adb logcat | grep "FATAL\|ERROR"`
- Check device compatibility
- Test on different Android version
- Report crash with logs

---

## 🎉 SUCCESS CRITERIA

### Ready for Production When:
- ✅ APK installs on all test devices
- ✅ Multiplayer works (no freezing)
- ✅ No blue screen (play 10+ games)
- ✅ 60 FPS during gameplay
- ✅ Smooth scene transitions
- ✅ Touch input responsive
- ✅ Memory stable (<250MB)
- ✅ No crashes (30-min session)
- ✅ Battery usage reasonable (<10%/30min)

---

**Last Updated:** May 3, 2026  
**Version:** 1.1 (All fixes applied)  
**Status:** Ready for Testing

