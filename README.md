# Aion

Aion is a weather-focused Garmin Connect IQ watch face for the **Forerunner 965**, written in Monkey C. It began as a separate project derived from [Hypnos](https://github.com/DonalGeraghty/hypnos).

## Features

- Large digital clock using the watch's 12/24-hour preference, with AM/PM in 12-hour mode.
- Current temperature, feels-like temperature and weather conditions.
- Custom symbols for clear skies, clouds, rain, snow, mixed precipitation, ice, thunderstorms, fog, haze and wind.
- A moon for clear and partly cloudy nights, using local sunrise/sunset when available. If sun times are unavailable, night is approximated as 20:00-06:00.
- Wind speed in km/h, compass direction and a matching bearing arrow.
- Daily high/low temperature and the next sunrise or sunset.
- Six-hour temperature trend, rain-probability bars and hour labels such as `17h`.
- Humidity, dew point, pressure in hPa and cloud cover.
- Weather observation age, highlighted in amber after 60 minutes.
- Minimal always-on mode: only a dim clock, repositioned periodically.

The layout targets the Forerunner 965's 454 x 454 round AMOLED screen. Temperature is displayed in Celsius. Weather comes from Garmin's cached weather APIs; data can be missing or old, and unavailable readings show `--`.

## Development setup

On Windows, install:

1. Visual Studio Code.
2. Java 11 or newer.
3. Garmin's **Monkey C** VS Code extension.
4. A Garmin Connect IQ SDK, plus the **Forerunner 965** device profile.

In VS Code, run **Monkey C: Open SDK Manager** to configure the SDK and download the device. Then run **Monkey C: Verify Installation**.

Generate a signing key with **Monkey C: Generate a Developer Key**, save it **outside this repository**, and configure **Monkey C: Developer Key Path** in VS Code settings. Keep the key backed up and do not commit it.

## Run in the simulator

Open this folder in VS Code, open a `.mc` file in `source/`, and press **F5**. Choose **Forerunner 965**.

If needed, create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "monkeyc",
      "request": "launch",
      "name": "Run App",
      "stopAtLaunch": false,
      "device": "${command:GetTargetDevice}"
    }
  ]
}
```

If VS Code says the app is running but no simulator window appears, stop debugging, close a stuck Garmin `simulator.exe` process in Task Manager, and launch again.

### Live and sample weather

- `monkey.jungle` includes live Garmin weather and excludes sample weather.
- `preview.jungle` includes sample weather and excludes live weather. Its face displays **Sample weather**.

For a sample preview from an SDK terminal, replace the key path below with your own:

```powershell
monkeyc -f preview.jungle -d fr965_sim -y C:\path\to\developer_key -o bin\Aion-preview.prg
connectiq
monkeydo bin\Aion-preview.prg fr965
```

Always use `monkey.jungle` for the physical watch.

## Install on your Forerunner 965

1. Run **Monkey C: Build for Device** in VS Code.
2. Select **Forerunner 965** and choose an output folder.
3. Connect the watch by USB.
4. Copy the signed `.prg` file into the watch's `GARMIN\APPS` folder.
5. Safely disconnect the watch.
6. Hold **UP/MENU**, choose **Watch Face**, select **Aion**, and apply it.

Publishing to the Connect IQ Store is not required for sideloading onto your own watch. Simulator builds are for preview; create a device build before installing.

## Checks

`source/AionVisualTests.mc` contains simulator tests covering weather categories, sunrise/sunset boundaries, wind formatting and bearings, icon drawing, and the clock-only sleep branch.

```powershell
monkeyc -f preview.jungle -d fr965_sim -y C:\path\to\developer_key -o bin\Aion-tests.prg -t
connectiq
monkeydo bin\Aion-tests.prg fr965 /t
```

The watch and preview builds have compiled successfully, and the four simulator tests have passed. Physical-watch validation is still required.

## Project files

- `source/AionView.mc`: layout, custom icons and weather handling.
- `source/AionApp.mc`: app entry point.
- `manifest.xml`: Forerunner 965 watch-face target and positioning permission for weather location/sun times.
- `resources/`: app name and launcher icon.
- `MVP_PLAN.md`: historical plan from the original sleep-focused design.

Build output, signing keys and local editor settings are excluded from Git.

## Garmin documentation

- [Getting started](https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/)
- [VS Code extension](https://developer.garmin.com/connect-iq/reference-guides/visual-studio-code-extension/)
- [First app and sideloading](https://developer.garmin.com/connect-iq/connect-iq-basics/your-first-app/)
- [Weather API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Weather.html)
