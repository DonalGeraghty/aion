using Toybox.Graphics as Graphics;
using Toybox.Math as Math;
using Toybox.System as System;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.WatchUi as WatchUi;
using Toybox.Weather as Weather;

const COLOR_TEXT = 0xF2F5FA;
const COLOR_MUTED = 0x9AAABA;
const COLOR_PANEL = 0x0C141D;
const COLOR_DETAIL = 0xBEC9D4;
const COLOR_CYAN = 0x3EE6F0;
const COLOR_BLUE = 0x438FFF;
const COLOR_WARM = 0xFFD080;

class AionView extends WatchUi.WatchFace {
    var _lowPower = false;
    var _scale = 1.0;
    var _timeFont;
    var _tempFont;
    var _valueFont;
    var _smallFont;
    var _labelFont;
    var _statusFont;
    var _weather = null;
    var _lastRead = null;
    // Allocate fixed lookup tables once rather than during every redraw.
    var _directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    var _secondaryLabels = ["Humidity", "Dew", "hPa", "Cloud"];
    var _conditionNames = ["CLEAR", "PARTLY CLOUDY", "MOSTLY CLOUDY", "RAIN", "SNOW", "WINDY", "THUNDERSTORMS", "WINTRY MIX", "FOG", "HAZY", "HAIL", "SCATTERED SHOWERS", "SCATTERED STORMS", "PRECIPITATION", "LIGHT RAIN", "HEAVY RAIN", "LIGHT SNOW", "HEAVY SNOW", "LIGHT RAIN / SNOW", "HEAVY RAIN / SNOW", "CLOUDY", "RAIN / SNOW", "PARTLY CLEAR", "MOSTLY CLEAR", "LIGHT SHOWERS", "SHOWERS", "HEAVY SHOWERS", "CHANCE OF SHOWERS", "CHANCE OF STORMS", "MIST", "DUST", "DRIZZLE", "TORNADO", "SMOKE", "ICE", "SAND", "SQUALL", "SANDSTORM", "VOLCANIC ASH", "HAZE", "FAIR", "HURRICANE", "TROPICAL STORM", "CHANCE OF SNOW", "CHANCE OF RAIN / SNOW", "CLOUDY / RAIN", "CLOUDY / SNOW", "CLOUDY / RAIN / SNOW", "FLURRIES", "FREEZING RAIN", "SLEET", "ICE / SNOW", "THIN CLOUDS", "UNKNOWN"];
    var _sunCache = null;

    function initialize() { WatchFace.initialize(); }
    function onLayout(dc) {
        _scale = dc.getWidth() / 454.0;
        _timeFont = font(72, Graphics.FONT_LARGE);
        _tempFont = font(46, Graphics.FONT_MEDIUM);
        _valueFont = font(22, Graphics.FONT_SMALL);
        _smallFont = font(19, Graphics.FONT_XTINY);
        _labelFont = labelFont(16);
        _statusFont = labelFont(14);
    }
    function labelFont(size) {
        if (Graphics has :getVectorFont) {
            var result = Graphics.getVectorFont({:face => ["RobotoRegular", "RobotoCondensedBold"], :size => (size * _scale).toNumber()});
            if (result != null) { return result; }
        }
        return Graphics.FONT_XTINY;
    }
    function font(size, fallback) {
        if (Graphics has :getVectorFont) {
            var result = Graphics.getVectorFont({:face => ["RobotoCondensedBold", "RobotoRegular"], :size => (size * _scale).toNumber()});
            if (result != null) { return result; }
        }
        return fallback;
    }
    function text(dc, x, y, value, face, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x * _scale, y * _scale, face, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    function line(dc, x1, y1, x2, y2, color, width) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(width * _scale);
        dc.drawLine(x1 * _scale, y1 * _scale, x2 * _scale, y2 * _scale);
        dc.setPenWidth(1);
    }
    function panel(dc, x, y, width, height) {
        dc.setColor(COLOR_PANEL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x * _scale, y * _scale, width * _scale, height * _scale, 12 * _scale);
    }
    function clockText() {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        return hour.format("%02d") + ":" + clock.min.format("%02d");
    }
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setAntiAlias(true);
        var now = Time.now();
        if (_lowPower) {
            // Move the reduced display every minute; no weather work in sleep.
            var slot = System.getClockTime().min % 3;
            text(dc, 227, 110 + slot * 110, clockText(), _tempFont, 0x586575);
            return;
        }
        var date = Gregorian.info(now, Time.FORMAT_MEDIUM);
        if (_lastRead == null || now.value() - _lastRead >= 900) {
            _weather = readWeather();
            _lastRead = now.value();
        }
        text(dc, 193, 37, date.day_of_week + " " + date.day.format("%02d") + " " + date.month, _smallFont, COLOR_MUTED);
        text(dc, 313, 37, System.getSystemStats().battery.format("%.0f") + "%", _smallFont, COLOR_DETAIL);
        text(dc, 227, 91, clockText(), _timeFont, COLOR_TEXT);
        if (!System.getDeviceSettings().is24Hour) {
            text(dc, 337, 106, System.getClockTime().hour < 12 ? "AM" : "PM", _labelFont, COLOR_MUTED);
        }
        var w = _weather;
        if (w == null) { w = emptyWeather(); }
        if (w[:display] == null) { formatWeather(w); }
        drawCondition(dc, 111, 165, w[:condition], isNight(w));
        text(dc, 216, 163, w[:display][:temperature], _tempFont, COLOR_CYAN);
        text(dc, 339, 150, "Feels like", _labelFont, COLOR_MUTED);
        text(dc, 339, 174, w[:display][:feels], _valueFont, COLOR_CYAN);
        text(dc, 227, 202, w[:display][:condition], _smallFont, COLOR_MUTED);
        panel(dc, 43, 220, 368, 48);
        text(dc, 108, 233, "Wind km/h", _labelFont, COLOR_MUTED);
        drawWind(dc, w);
        text(dc, 231, 233, "High / low", _labelFont, COLOR_MUTED);
        text(dc, 231, 254, w[:display][:highLow], _smallFont, COLOR_CYAN);
        text(dc, 351, 233, w[:display][:sunLabel], _labelFont, COLOR_MUTED);
        text(dc, 351, 254, w[:sunTime], _smallFont, COLOR_WARM);
        var visibleHours = futureHours(w[:hours], now.value());
        drawForecast(dc, visibleHours);
        // A quiet divider leaves these secondary readings on the black face.
        line(dc, 105, 381, 349, 381, COLOR_PANEL, 1);
        var values = w[:display][:secondary];
        for (var i = 0; i < 4; i += 1) {
            var x = 125 + i * 68;
            text(dc, x, 392, _secondaryLabels[i], _labelFont, COLOR_MUTED);
            text(dc, x, 412, values[i], _smallFont, COLOR_DETAIL);
        }
        var age = "Weather unavailable";
        var ageColor = COLOR_MUTED;
        if (w[:sample]) { age = "Sample weather"; }
        else {
            if (w[:observed] != null) {
                var minutes = clamp((now.value() - w[:observed]) / 60, 0, 99999).toNumber();
                age = (w[:conditionsCached] ? "Cached " : "Observed ") + minutes.toString() + "m ago";
                if (minutes >= 60 || w[:conditionsCached]) { ageColor = COLOR_WARM; }
            }
            if (w[:forecastCached] && visibleHours.size() > 0) {
                age = (w[:observed] != null ? age + " | " : "") + "Forecast cached";
                ageColor = COLOR_WARM;
            }
        }
        text(dc, 227, 436, age, _statusFont, ageColor);
    }
    function sentenceCase(value) {
        if (value.length() == 0) { return value; }
        return value.substring(0, 1).toUpper() + value.substring(1, value.length()).toLower();
    }
    function number(value, suffix) {
        if (value == null) { return "--"; }
        return Math.round(value).format("%d") + suffix;
    }
    function degrees(value) { return number(value, "°"); }
    function clamp(value, low, high) {
        if (value < low) { return low; }
        if (value > high) { return high; }
        return value;
    }
    function windText(w) {
        if (w[:wind] == null) { return "--"; }
        if (w[:wind] < 0.14) { return "Calm"; }
        var direction = "";
        if (w[:bearing] != null) { direction = _directions[((normalizedBearing(w[:bearing]) + 22.5) / 45).toNumber() % 8] + " "; }
        return direction + number(w[:wind].toFloat() * 3.6, "");
    }
    function normalizedBearing(bearing) { return ((bearing % 360) + 360) % 360; }
    function drawWind(dc, w) {
        var hasArrow = w[:wind] != null && w[:wind] >= 0.14 && w[:bearing] != null;
        text(dc, hasArrow ? 122 : 108, 254, w[:display][:wind], _smallFont, COLOR_TEXT);
        if (!hasArrow) { return; }
        // Match the compass bearing beside the speed: north points up.
        var angle = normalizedBearing(w[:bearing]) * Math.PI / 180;
        var dx = Math.sin(angle);
        var dy = -Math.cos(angle);
        var tipX = 77 + dx * 8;
        var tipY = 254 + dy * 8;
        line(dc, 77 - dx * 8, 254 - dy * 8, tipX, tipY, COLOR_DETAIL, 2);
        line(dc, tipX, tipY, tipX - dx * 5 - dy * 4, tipY - dy * 5 + dx * 4, COLOR_DETAIL, 2);
        line(dc, tipX, tipY, tipX - dx * 5 + dy * 4, tipY - dy * 5 - dx * 4, COLOR_DETAIL, 2);
    }
    function isNight(w) {
        return isNightAt(w, Time.now().value(), System.getClockTime().hour);
    }
    function isNightAt(w, now, hour) {
        if (w[:sunrise] != null && w[:sunset] != null) {
            return now < w[:sunrise] || now >= w[:sunset];
        }
        // Approximate only when Garmin cannot supply local sun times.
        return hour < 6 || hour >= 20;
    }
    function conditionName(condition) {
        if (condition == null || condition < 0 || condition > 53) { return "CONDITIONS UNAVAILABLE"; }

        return _conditionNames[condition];
    }
    function conditionStyle(condition) {
        if (condition == null) { return :unknown; }
        switch (condition) {
            case Weather.CONDITION_CLEAR:
            case Weather.CONDITION_FAIR: return :clear;
            case Weather.CONDITION_PARTLY_CLOUDY:
            case Weather.CONDITION_PARTLY_CLEAR:
            case Weather.CONDITION_MOSTLY_CLEAR:
            case Weather.CONDITION_THIN_CLOUDS: return :partial;
            case Weather.CONDITION_MOSTLY_CLOUDY:
            case Weather.CONDITION_CLOUDY: return :cloud;
            case Weather.CONDITION_THUNDERSTORMS:
            case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
            case Weather.CONDITION_CHANCE_OF_THUNDERSTORMS: return :storm;
            case Weather.CONDITION_SNOW:
            case Weather.CONDITION_LIGHT_SNOW:
            case Weather.CONDITION_HEAVY_SNOW:
            case Weather.CONDITION_CHANCE_OF_SNOW:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW:
            case Weather.CONDITION_FLURRIES: return :snow;
            case Weather.CONDITION_WINTRY_MIX:
            case Weather.CONDITION_LIGHT_RAIN_SNOW:
            case Weather.CONDITION_HEAVY_RAIN_SNOW:
            case Weather.CONDITION_RAIN_SNOW:
            case Weather.CONDITION_CHANCE_OF_RAIN_SNOW:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW: return :mix;
            case Weather.CONDITION_HAIL:
            case Weather.CONDITION_ICE:
            case Weather.CONDITION_FREEZING_RAIN:
            case Weather.CONDITION_SLEET:
            case Weather.CONDITION_ICE_SNOW: return :ice;
            case Weather.CONDITION_FOG:
            case Weather.CONDITION_MIST: return :fog;
            case Weather.CONDITION_HAZY:
            case Weather.CONDITION_HAZE:
            case Weather.CONDITION_DUST:
            case Weather.CONDITION_SMOKE:
            case Weather.CONDITION_SAND:
            case Weather.CONDITION_VOLCANIC_ASH: return :haze;
            case Weather.CONDITION_WINDY:
            case Weather.CONDITION_SQUALL:
            case Weather.CONDITION_SANDSTORM:
            case Weather.CONDITION_TORNADO:
            case Weather.CONDITION_HURRICANE:
            case Weather.CONDITION_TROPICAL_STORM: return :wind;
            case Weather.CONDITION_RAIN:
            case Weather.CONDITION_SCATTERED_SHOWERS:
            case Weather.CONDITION_UNKNOWN_PRECIPITATION:
            case Weather.CONDITION_LIGHT_RAIN:
            case Weather.CONDITION_HEAVY_RAIN:
            case Weather.CONDITION_LIGHT_SHOWERS:
            case Weather.CONDITION_SHOWERS:
            case Weather.CONDITION_HEAVY_SHOWERS:
            case Weather.CONDITION_CHANCE_OF_SHOWERS:
            case Weather.CONDITION_DRIZZLE:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN: return :rain;
        }
        return :unknown;
    }
    function circle(dc, x, y, radius, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x * _scale, y * _scale, radius * _scale);
    }
    function drawSky(dc, x, y, night) {
        if (night) {
            circle(dc, x, y, 17, COLOR_DETAIL);
            circle(dc, x + 8, y - 6, 15, Graphics.COLOR_BLACK);
            line(dc, x + 22, y + 8, x + 22, y + 14, COLOR_DETAIL, 1);
            line(dc, x + 19, y + 11, x + 25, y + 11, COLOR_DETAIL, 1);
        } else {
            circle(dc, x, y, 12, COLOR_WARM);
            for (var i = 0; i < 8; i += 1) {
                var angle = i * Math.PI / 4;
                line(dc, x + Math.cos(angle) * 17, y + Math.sin(angle) * 17, x + Math.cos(angle) * 22, y + Math.sin(angle) * 22, COLOR_WARM, 2);
            }
        }
    }
    function drawCloud(dc, x, y) {
        circle(dc, x - 13, y + 3, 10, COLOR_TEXT);
        circle(dc, x, y - 4, 14, COLOR_TEXT);
        circle(dc, x + 15, y + 3, 10, COLOR_TEXT);
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle((x - 14) * _scale, y * _scale, 29 * _scale, 13 * _scale);
    }
    function drawSnowflake(dc, x, y, radius) {
        for (var i = 0; i < 3; i += 1) {
            var angle = i * Math.PI / 3;
            var dx = Math.cos(angle) * radius;
            var dy = Math.sin(angle) * radius;
            line(dc, x - dx, y - dy, x + dx, y + dy, COLOR_CYAN, 2);
        }
    }
    function drawCondition(dc, x, y, condition, night) {
        var style = conditionStyle(condition);
        if (style == :unknown) { text(dc, x, y, "?", _tempFont, COLOR_MUTED); return; }
        if (style == :clear) { drawSky(dc, x, y, night); return; }
        if (style == :partial) { drawSky(dc, x - 9, y - 9, night); drawCloud(dc, x + 3, y + 5); return; }
        if (style == :wind) {
            for (var i = 0; i < 3; i += 1) {
                var row = y - 12 + i * 12;
                line(dc, x - 23 + i * 3, row, x + 17 - i * 4, row, COLOR_DETAIL, 3);
                line(dc, x + 17 - i * 4, row, x + 20 - i * 4, row - 4, COLOR_DETAIL, 3);
            }
            return;
        }
        if (style == :fog || style == :haze) {
            drawCloud(dc, x, y - 9);
            for (var f = 0; f < 3; f += 1) {
                line(dc, x - 24 + f * 4, y + 10 + f * 7, x + 24 - f * 4, y + 10 + f * 7, style == :haze ? COLOR_WARM : COLOR_MUTED, 2);
            }
            return;
        }
        drawCloud(dc, x, y - 6);
        if (style == :storm) {
            line(dc, x + 5, y + 8, x - 3, y + 19, COLOR_WARM, 4);
            line(dc, x - 3, y + 19, x + 5, y + 19, COLOR_WARM, 4);
            line(dc, x + 5, y + 19, x - 4, y + 30, COLOR_WARM, 4);
        } else if (style == :snow) {
            drawSnowflake(dc, x - 12, y + 20, 5);
            drawSnowflake(dc, x + 12, y + 20, 5);
        } else if (style == :mix) {
            line(dc, x - 12, y + 13, x - 16, y + 23, COLOR_BLUE, 2);
            drawSnowflake(dc, x + 11, y + 20, 5);
        } else if (style == :ice) {
            for (var h = 0; h < 3; h += 1) { circle(dc, x - 14 + h * 14, y + 20, 3, COLOR_CYAN); }
        } else if (style == :rain) {
            for (var r = 0; r < 3; r += 1) { line(dc, x - 12 + r * 13, y + 13, x - 16 + r * 13, y + 23, COLOR_BLUE, 2); }
        }
    }
    // Only the display is filtered, so elapsed hours disappear between API reads.
    function futureHours(hours, now) {
        var visible = [];
        for (var i = 0; i < hours.size(); i += 1) {
            if (hours[i][:at] == null || hours[i][:at] >= now) {
                visible.add(hours[i]);
            }
        }
        return visible;
    }
    // Same future-hour payload means Garmin may still be serving the same snapshot.
    // Don't restart the cache fallback TTL just because the API returned it again.
    function sameForecast(previousHours, hours) {
        if (previousHours.size() != hours.size()) { return false; }
        for (var i = 0; i < hours.size(); i += 1) {
            if (previousHours[i][:at] != hours[i][:at] ||
                previousHours[i][:temp] != hours[i][:temp] ||
                previousHours[i][:rain] != hours[i][:rain]) { return false; }
        }
        return true;
    }
    function drawForecast(dc, hours) {
        text(dc, 134, 280, "Hourly temperature", _labelFont, COLOR_CYAN);
        text(dc, 343, 280, "Rain %", _labelFont, COLOR_BLUE);
        if (hours.size() == 0) { text(dc, 227, 325, "Forecast unavailable", _smallFont, COLOR_MUTED); return; }
        var min = null;
        var max = null;
        for (var i = 0; i < hours.size(); i += 1) {
            var t = hours[i][:temp];
            if (t != null) {
                if (min == null || t < min) { min = t; }
                if (max == null || t > max) { max = t; }
            }
        }
        var previousX = null;
        var previousY = null;
        for (var j = 0; j < hours.size(); j += 1) {
            var h = hours[j];
            var x = 77 + j * 60;
            var y = 314;
            if (h[:temp] != null) {
                if (max > min) { y = 320 - (h[:temp] - min) / (max - min).toFloat() * 10; }
                if (previousX != null) { line(dc, previousX, previousY, x, y, COLOR_CYAN, 2); }
                dc.setColor(COLOR_CYAN, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x * _scale, y * _scale, 3 * _scale);
                previousX = x; previousY = y;
            } else { previousX = null; }
            text(dc, x, 295, h[:tempText], _labelFont, COLOR_CYAN);
            if (h[:rain] != null) {
                var height = clamp(h[:rain], 0, 100) * 0.20;
                // A zero chance leaves the rain track empty.
                dc.setColor(COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                if (height > 0) { dc.fillRoundedRectangle((x - 9) * _scale, (343 - height) * _scale, 18 * _scale, height * _scale, 2 * _scale); }
            }
            text(dc, x, 353, h[:rainText], _labelFont, COLOR_BLUE);
            text(dc, x, 371, h[:label] + "h", _labelFont, COLOR_MUTED);
        }
    }
    // Weather-only strings are prepared on refresh, never on normal redraw.
    function formatWeather(w) {
        var hours = w[:hours];
        for (var i = 0; i < hours.size(); i += 1) {
            hours[i][:tempText] = degrees(hours[i][:temp]);
            hours[i][:rainText] = number(hours[i][:rain], "");
        }
        w[:display] = {
            :temperature=>degrees(w[:temperature]),
            :feels=>degrees(w[:feels]),
            :condition=>sentenceCase(conditionName(w[:condition])),
            :highLow=>degrees(w[:high]) + " / " + degrees(w[:low]),
            :wind=>windText(w),
            :sunLabel=>sentenceCase(w[:sunLabel]),
            :secondary=>[number(w[:humidity], "%"), degrees(w[:dew]),
                         number(w[:pressure], ""), number(w[:cloud], "%")]
        };
    }
    function emptyWeather() {
        return {:temperature=>null, :feels=>null, :condition=>null, :high=>null, :low=>null, :wind=>null, :bearing=>null, :humidity=>null, :dew=>null, :pressure=>null, :cloud=>null, :observed=>null, :sunrise=>null, :sunset=>null, :sunLabel=>"SUNSET", :sunTime=>"--", :sunEventAt=>null, :hours=>[], :sample=>false, :conditionsCached=>false, :forecastCached=>false, :forecastFetchedAt=>null, :display=>null};
    }
    function keepValue(w, key, value) {
        if (value != null) { w[key] = value; }
    }
    // Garmin's conditions and hourly forecast caches can fail independently.
    (:live)
    function readWeather() {
        var w = emptyWeather();
        var now = Time.now().value();
        var previous = _weather;
        var c = null;
        try { c = Weather.getCurrentConditions(); }
        catch (ex) { System.println("Aion current conditions: " + ex.toString()); }
        if (c != null) {
            w[:temperature] = c.temperature; w[:feels] = c.feelsLikeTemperature;
            w[:condition] = c.condition; w[:high] = c.highTemperature; w[:low] = c.lowTemperature;
            w[:wind] = c.windSpeed; w[:bearing] = c.windBearing; w[:humidity] = c.relativeHumidity;
            w[:dew] = c.dewPoint; w[:cloud] = c.cloudCover;
            if (c.pressure != null) { w[:pressure] = c.pressure / 100.0; }
            if (c.observationTime != null) { w[:observed] = c.observationTime.value(); }
            try { setSunCached(w, c.observationLocationPosition); }
            catch (ex) { System.println("Aion sunrise/sunset: " + ex.toString()); }
        }
        // Keep prior data for at most three hours, including partial responses.
        if (previous != null && previous[:observed] != null &&
            now >= previous[:observed] && now - previous[:observed] <= 10800) {
            var keys = [:temperature, :feels, :condition, :high, :low,
                        :wind, :bearing, :humidity, :dew, :pressure, :cloud];
            for (var k = 0; k < keys.size(); k += 1) {
                var key = keys[k];
                if (w[key] == null && previous[key] != null) {
                    w[key] = previous[key];
                    w[:conditionsCached] = true;
                }
            }
            if (w[:observed] == null) {
                w[:observed] = previous[:observed];
                w[:conditionsCached] = true;
            }
        }
        var forecast = null;
        try { forecast = Weather.getHourlyForecast(); }
        catch (ex) { System.println("Aion hourly forecast: " + ex.toString()); }
        if (forecast != null) {
            try {
                for (var i = 0; i < forecast.size() && w[:hours].size() < 6; i += 1) {
                    var h = forecast[i];
                    if (h.forecastTime != null && h.forecastTime.value() >= now) {
                        var date = Gregorian.info(h.forecastTime, Time.FORMAT_SHORT);
                        w[:hours].add({:temp=>h.temperature, :rain=>h.precipitationChance,
                                       :label=>date.hour.format("%02d"), :at=>h.forecastTime.value()});
                    }
                }
                if (w[:hours].size() > 0) {
                    // Compare overlapping future hours: dropping an elapsed hour
                    // by itself does not constitute newly published forecast data.
                    if (previous != null && previous[:forecastFetchedAt] != null &&
                        sameForecast(futureHours(previous[:hours], now), w[:hours])) {
                        w[:forecastFetchedAt] = previous[:forecastFetchedAt];
                    } else {
                        w[:forecastFetchedAt] = now;
                    }
                    if (now - w[:forecastFetchedAt] > 5400) {
                        w[:forecastCached] = true;
                    }
                }
            } catch (ex) {
                System.println("Aion forecast processing: " + ex.toString());
                w[:hours] = [];
            }
        }
        // Keep future-only forecast entries for up to 90 minutes after the last distinct snapshot.
        if (w[:hours].size() == 0 && previous != null &&
            previous[:forecastFetchedAt] != null &&
            now >= previous[:forecastFetchedAt] && now - previous[:forecastFetchedAt] <= 5400) {
            var oldHours = previous[:hours];
            for (var j = 0; j < oldHours.size(); j += 1) {
                if (oldHours[j][:at] != null && oldHours[j][:at] >= now) {
                    w[:hours].add(oldHours[j]);
                }
            }
            if (w[:hours].size() > 0) {
                w[:forecastFetchedAt] = previous[:forecastFetchedAt];
                w[:forecastCached] = true;
            }
        }
        formatWeather(w);
        return w;
    }
    // Recompute astronomical data only when the local date or location changes.
    // Keep a copy of the computed daily event across normal weather refreshes.
    function setSunCached(w, location) {
        if (location == null) { return; }
        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var coordinates = location.toDegrees();
        var key = today.year.toString() + "-" + today.month.toString() + "-" +
                  today.day.toString() + ":" + coordinates[0].toString() + ":" +
                  coordinates[1].toString();
        if (_sunCache != null && _sunCache[:key] == key &&
            _sunCache[:eventAt] != null && Time.now().value() < _sunCache[:eventAt]) {
            w[:sunrise] = _sunCache[:sunrise];
            w[:sunset] = _sunCache[:sunset];
            w[:sunLabel] = _sunCache[:sunLabel];
            w[:sunTime] = _sunCache[:sunTime];
            w[:sunEventAt] = _sunCache[:eventAt];
            return;
        }
        setSun(w, location);
        _sunCache = {:key=>key, :sunrise=>w[:sunrise], :sunset=>w[:sunset],
                     :sunLabel=>w[:sunLabel], :sunTime=>w[:sunTime],
                     :eventAt=>w[:sunEventAt]};
    }
    function setSun(w, location) {
        if (location == null) { return; }
        var now = Time.now();
        var sunrise = Weather.getSunrise(location, now);
        var sunset = Weather.getSunset(location, now);
        if (sunrise != null) { w[:sunrise] = sunrise.value(); }
        if (sunset != null) { w[:sunset] = sunset.value(); }
        var event = null;
        if (sunrise != null && sunrise.value() > now.value()) { event = sunrise; w[:sunLabel] = "SUNRISE"; }
        else if (sunset != null && sunset.value() > now.value()) { event = sunset; }
        else { event = Weather.getSunrise(location, new Time.Moment(now.value() + 86400)); w[:sunLabel] = "SUNRISE"; }
        if (event != null) {
            var date = Gregorian.info(event, Time.FORMAT_SHORT);
            w[:sunTime] = date.hour.format("%02d") + ":" + date.min.format("%02d");
            w[:sunEventAt] = event.value();
        }
    }
    (:preview)
    function readWeather() {
        var w = emptyWeather();
        w[:sample] = true; w[:temperature] = 16; w[:feels] = 13;
        w[:condition] = Weather.CONDITION_PARTLY_CLOUDY; w[:high] = 18; w[:low] = 9;
        w[:wind] = 5; w[:bearing] = 225; w[:humidity] = 82; w[:dew] = 11;
        w[:pressure] = 1013; w[:cloud] = 75; w[:sunTime] = "18:34";
        var temperatures = [16, 17, 18, 17, 15, 14];
        var rain = [10, 20, 35, 65, 80, 40];
        var hour = System.getClockTime().hour;
        for (var i = 0; i < 6; i += 1) { w[:hours].add({:temp=>temperatures[i], :rain=>rain[i], :label=>((hour + i + 1) % 24).format("%02d")}); }
        formatWeather(w);
        return w;
    }
    function onEnterSleep() { _lowPower = true; WatchUi.requestUpdate(); }
    function onExitSleep() { _lowPower = false; WatchUi.requestUpdate(); }
}
