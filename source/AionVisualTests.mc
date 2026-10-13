using Toybox.Graphics;
using Toybox.Test;
using Toybox.Weather;

(:test)
function weatherSymbols(logger) {
    var view = new AionView();
    Test.assert(view.conditionStyle(Weather.CONDITION_CLEAR) == :clear);
    Test.assert(view.conditionStyle(Weather.CONDITION_PARTLY_CLEAR) == :partial);
    Test.assert(view.conditionStyle(Weather.CONDITION_MOSTLY_CLOUDY) == :cloud);
    Test.assert(view.conditionStyle(Weather.CONDITION_THUNDERSTORMS) == :storm);
    Test.assert(view.conditionStyle(Weather.CONDITION_HEAVY_SNOW) == :snow);
    Test.assert(view.conditionStyle(Weather.CONDITION_LIGHT_RAIN_SNOW) == :mix);
    Test.assert(view.conditionStyle(Weather.CONDITION_FREEZING_RAIN) == :ice);
    Test.assert(view.conditionStyle(Weather.CONDITION_FOG) == :fog);
    Test.assert(view.conditionStyle(Weather.CONDITION_SMOKE) == :haze);
    Test.assert(view.conditionStyle(Weather.CONDITION_TORNADO) == :wind);
    Test.assert(view.conditionStyle(Weather.CONDITION_HEAVY_RAIN) == :rain);
    Test.assert(view.conditionStyle(null) == :unknown);
    Test.assert(view.conditionStyle(Weather.CONDITION_UNKNOWN) == :unknown);
    Test.assert(view.conditionStyle(999) == :unknown);
    // Every currently defined condition has an intentional visual category.
    for (var condition = 0; condition < Weather.CONDITION_UNKNOWN; condition += 1) {
        Test.assert(view.conditionStyle(condition) != :unknown);
    }
    return true;
}

(:test)
function daylightBoundaries(logger) {
    var view = new AionView();
    var w = view.emptyWeather();
    w[:sunrise] = 100; w[:sunset] = 200;
    Test.assert(view.isNightAt(w, 99, 12));
    Test.assert(!view.isNightAt(w, 100, 0));
    Test.assert(!view.isNightAt(w, 199, 0));
    Test.assert(view.isNightAt(w, 200, 12));
    w[:sunrise] = null;
    Test.assert(view.isNightAt(w, 150, 5));
    Test.assert(!view.isNightAt(w, 150, 6));
    Test.assert(!view.isNightAt(w, 150, 19));
    Test.assert(view.isNightAt(w, 150, 20));
    return true;
}

(:test)
function windBearings(logger) {
    var view = new AionView();
    var w = view.emptyWeather();
    Test.assert(view.windText(w).equals("--"));
    w[:wind] = 0; w[:bearing] = 225;
    Test.assert(view.windText(w).equals("Calm"));
    w[:wind] = 5;
    Test.assert(view.windText(w).equals("SW 18"));
    w[:bearing] = 360;
    Test.assert(view.windText(w).equals("N 18"));
    w[:bearing] = -90;
    Test.assert(view.windText(w).equals("W 18"));
    w[:bearing] = null;
    Test.assert(view.windText(w).equals("18"));
    Test.assert(view.normalizedBearing(720) == 0);
    return true;
}

(:test)
function drawWeatherAndSleep(logger) {
    var bitmapRef = Graphics.createBufferedBitmap({:width=>80, :height=>80});
    var bitmap = bitmapRef.get();
    var dc = bitmap.getDc();
    var view = new AionView();
    view.onLayout(dc);
    view._scale = 1.0;
    for (var condition = 0; condition <= Weather.CONDITION_UNKNOWN; condition += 1) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        view.drawCondition(dc, 40, 40, condition, false);
        view.drawCondition(dc, 40, 40, condition, true);
    }
    // The sleep branch draws only time and skips weather refresh entirely.
    view._lowPower = true;
    view.onUpdate(dc);
    Test.assert(view._lastRead == null);
    Test.assert(view._weather == null);
    return true;
}
