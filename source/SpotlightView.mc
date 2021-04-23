using Toybox.WatchUi;
using Toybox.Graphics as Gfx;
using Toybox.Lang;
using Toybox.System as Sys;
using Toybox.Application.Properties;

class SpotlightView extends WatchUi.WatchFace {

    const BACKGROUND_COLOR = Gfx.COLOR_BLACK;
    const HASH_MARK_COLOR = Gfx.COLOR_WHITE;
    const HOUR_LINE_COLOR = Gfx.COLOR_RED;
    const HASH_MARK_LOW_POWER_COLOR = Gfx.COLOR_DK_GRAY;
    const HOUR_LINE_LOW_POWER_COLOR = Gfx.COLOR_DK_RED;
    // Starting with a clock exactly the size of the face, how many
    // times to zoom in.
    var zoom_factor as Float = 2.1f;
    // How far from the center of the clock the middle of the face should be
    // 0 means don't move, 1 means the edge of the clock will be in the middle
    // of the face
    var focal_point as Float = 0.8f;
    // How far from the center of the clock the number should be printed
    var text_position as Float = 0.8f;
    var text_visible as boolean = true;
    var text_font = Gfx.FONT_SMALL;

    // Screen refers to the actual display, Clock refers to the virtual clock
    // that we're zooming in on.
    var screen_width, screen_height;
    var screen_radius;
    var screen_center_x, screen_center_y;
    var clock_radius;

    // Whether or not we're in low-power mode
    var low_power as Boolean;

    // Instead of an Array of Objects, separate Arrays, because older watches
    // can't handle lots of Objects
    const NUM_HASH_MARKS = 72;
	var hash_marks_angle as Array<Float> = new Float[NUM_HASH_MARKS]; // Angle in rad
	var hash_marks_width as Array<Number> = new Float[NUM_HASH_MARKS]; // Width of mark in pixels
	var hash_marks_clock_xo as Array<Float> = new Float[NUM_HASH_MARKS]; // Outside X coordinate of mark
    // Clock coordinates in -1.0 to +1.0 range
	var hash_marks_clock_yo as Array<Float> = new Float[NUM_HASH_MARKS]; // Outside Y coordinate of mark
	var hash_marks_clock_xi as Array<Float> = new Float[NUM_HASH_MARKS]; // Inside X     "
	var hash_marks_clock_yi as Array<Float> = new Float[NUM_HASH_MARKS]; // Inside Y     "
	var hash_marks_label as Array<String> = new [NUM_HASH_MARKS]; // Hour label

    function initialize() {
        WatchFace.initialize();
        low_power = false;
    }

    // Load your resources here
    function onLayout(dc) {
        if (Toybox.Application has :Properties) {
            zoom_factor = Properties.getValue("zoomFactor");
            focal_point = Properties.getValue("focalPoint");
            text_position = Properties.getValue("textPosition");
            text_visible = Properties.getValue("textVisible");
            text_font = Properties.getValue("font");
        }

        // get screen dimensions
        screen_width = dc.getWidth();
        screen_height = dc.getHeight();
        // if the screen isn't round/square, we'll use a diameter
        // that's the average of the two. And of course radius is
        // half that.
        screen_radius = (screen_width + screen_height) / 4.0f;
        // -1 seems to line up better in the simulator
        screen_center_x = screen_width / 2 - 1;
        screen_center_y = screen_height / 2 - 1;

        clock_radius = screen_radius * zoom_factor;

        // pre-calculate as much as we can using static parameters
        for(var i = 0; i < NUM_HASH_MARKS; i += 1) {
            var angle as Float = ((i as Float) / 72.0f) * 2 * Math.PI;
            var length as Float;
            if (i % 6 == 0) {
                // Hour hashes are the longest
                length = 0.10f;
                hash_marks_width[i] = 3;
                var hour as Number = i / 6;
                if (hour == 0) {
                    hour = 12;
                }
                hash_marks_label[i] = hour.format("%d");
            } else {
                if (i % 3 == 0) {
                    // Half hour ticks
                    length = 0.05f;
                    hash_marks_width[i] = 2;
                } else {
                    // 10 minute ticks
                    length = 0.025f;
                    hash_marks_width[i] = 1;
                }
                hash_marks_label[i] = "";
            }
            hash_marks_clock_xo[i] = Math.sin(angle);
            hash_marks_clock_yo[i] = -Math.cos(angle);
            hash_marks_clock_xi[i] = hash_marks_clock_xo[i] * (1 - length);
            hash_marks_clock_yi[i] = hash_marks_clock_yo[i] * (1 - length);
        }
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
    	var clockTime = Sys.getClockTime();
        // calculate angle for hour hand for the current time
        var time_seconds = ((((clockTime.hour % 12) * 60) + clockTime.min) * 60) + clockTime.sec;
        var time_angle = Math.PI * 2 * time_seconds / (12 * 60 * 60);

    	// setAntiAlias has only been around since 3.2.0
    	// this way we support older models
	    if(dc has :setAntiAlias) {
	        dc.setAntiAlias(true);
	    }
        // Clear the screen
        dc.setColor(BACKGROUND_COLOR, BACKGROUND_COLOR);
        dc.clear();

        drawHashMarks(dc, time_angle);

        drawHourLine(dc, time_angle);
    }

    function onPartialUpdate( dc ) {
    	onUpdate(dc);
    }

    function drawHashMarks(dc, angle) {
        if (low_power) {
            dc.setColor(HASH_MARK_LOW_POWER_COLOR, BACKGROUND_COLOR);
        } else {
            dc.setColor(HASH_MARK_COLOR, BACKGROUND_COLOR);
        }
        // focal_point * clock_radius * Math.sin(angle) ==
        //    the offset from center of clock to the focal point.
        // Combine them with screen center to bring focal point
        // to the center of the screen.
        // Add 0.5f to turn the implicit floor that drawLine does
        // into a round.
        // This is much much faster than using Math.round(), which
        // isn't available on older platforms. We're only dealing
        // with positive X/Y values, so this works nicely.
        var clock_center_x as Float = screen_center_x - focal_point * clock_radius * Math.sin(angle) + 0.5f;
        var clock_center_y as Float = screen_center_y + focal_point * clock_radius * Math.cos(angle) + 0.5f;
        var index_guess = (72.0f * angle / (2 * Math.PI)).toNumber();
        var dist;
        for (var i = 0; i < NUM_HASH_MARKS; ++i) {
            dist = (i - index_guess).abs();
            if (dist <= 9 || dist >= 63) {
                dc.setPenWidth(hash_marks_width[i]);
                // outside X, outside Y, inside X, inside Y
                var xo = clock_center_x + clock_radius * hash_marks_clock_xo[i];
                var yo = clock_center_y + clock_radius * hash_marks_clock_yo[i];
                var xi = clock_center_x + clock_radius * hash_marks_clock_xi[i];
                var yi = clock_center_y + clock_radius * hash_marks_clock_yi[i];
                dc.drawLine(xo, yo, xi, yi);
                // Digits trigger burn-in protection, so don't draw them in 
                // low power mode
                if (!low_power && text_visible && hash_marks_label[i] != "") {
                    var text_x = clock_center_x + clock_radius * hash_marks_clock_xo[i] * text_position;
                    var text_y = clock_center_y + clock_radius * hash_marks_clock_yo[i] * text_position;
                    dc.drawText(text_x, text_y, text_font, hash_marks_label[i],
                                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
                }
            }
        }
    }

    function drawHourLine(dc, angle) {
        var x1, y1, x2, y2 as Number;
        // 2 * radius so that we definitely overshoot, for square screens
        // Again, adding 0.5f to do implicit round instead of floor in
        // drawLine.
        if (low_power) {
            // For burn-in protection on OLED screens, don't draw the hour
            // line at the center of the screen. Instead we do two thinner
            // lines near the edges of the screen. This close to the center,
            // a width of 2 actually triggered detection at the tip.
            dc.setPenWidth(1);
            dc.setColor(HOUR_LINE_LOW_POWER_COLOR, BACKGROUND_COLOR);
            x1 = screen_center_x + 2 * screen_radius * Math.sin(angle) + 0.5f;
            y1 = screen_center_y - 2 * screen_radius * Math.cos(angle) + 0.5f;
            x2 = screen_center_x + 0.5 * screen_radius * Math.sin(angle) + 0.5f;
            y2 = screen_center_y - 0.5 * screen_radius * Math.cos(angle) + 0.5f;
            dc.drawLine(x1, y1, x2, y2);
            x1 = screen_center_x - 2 * screen_radius * Math.sin(angle) + 0.5f;
            y1 = screen_center_y + 2 * screen_radius * Math.cos(angle) + 0.5f;
            x2 = screen_center_x - 0.5 * screen_radius * Math.sin(angle) + 0.5f;
            y2 = screen_center_y + 0.5 * screen_radius * Math.cos(angle) + 0.5f;
            dc.drawLine(x1, y1, x2, y2);
        } else {
            dc.setPenWidth(2);
            dc.setColor(HOUR_LINE_COLOR, BACKGROUND_COLOR);
            x1 = screen_center_x + 2 * screen_radius * Math.sin(angle) + 0.5f;
            y1 = screen_center_y - 2 * screen_radius * Math.cos(angle) + 0.5f;
            x2 = screen_center_x - 2 * screen_radius * Math.sin(angle) + 0.5f;
            y2 = screen_center_y + 2 * screen_radius * Math.cos(angle) + 0.5f;
            dc.drawLine(x1, y1, x2, y2);
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
        low_power = false;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
        low_power = true;
    }

}
