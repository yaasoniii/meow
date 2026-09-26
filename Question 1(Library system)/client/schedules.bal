import ballerina/io;

function scheduleMenu() returns error? {
    boolean back = false;
    while !back {
        io:println("\n---------------- SCHEDULE MANAGER ----------------");
        io:println("1. View schedules for an asset");
        io:println("2. Add a schedule (servicing or booking)");
        io:println("3. Remove a schedule");
        io:println("0. Back to main menu");
        string choice = prompt("Select an option");
        match choice {
            "1" => { viewSchedules(); }
            "2" => { finish(addSchedule()); }
            "3" => { removeSchedule(); }
            "0" => { back = true; }
            _ => { io:println("Invalid option."); }
        }
    }
}

function viewSchedules() {
    string assetTag = prompt("Asset tag");
    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }

    Asset? asset = fetchAsset(assetTag);

    if asset is () {
        return;
    }

    io:println("\n-- Schedules for " + asset.assetTag + " --");

    if asset.schedules.length() == 0 {
        io:println("No schedules found.");
        return;
    }

    string today = todayIso();
    foreach Schedule schedule in asset.schedules {
        string flag = schedule.'type == "MAINTENANCE" && schedule.dueDate < today
            ? "  << OVERDUE"
            : "";
        io:println(
            "[" + schedule.scheduleId + "] " +
            describeSchedule(schedule) + " - " +
            schedule.description + flag
        );
    }
}

function addSchedule() returns error? {
    io:println("(Enter 0 at any prompt to cancel)");
    string assetTag = check ask("Asset tag");
    string scheduleId = check ask("Schedule ID");
    string scheduleType = check selectScheduleType();

    // A booking either takes whole day(s) or a time slot within one day.
    string? timeSlot = ();
    if scheduleType == "BOOKING" {
        io:println("Booking length:");
        io:println("  1. Day(s)");
        io:println("  2. Hours within a day");
        io:println("  0. Cancel");
        string length = check ask("Select option number");
        while length != "1" && length != "2" {
            io:println("Please enter 1, 2 or 0 to cancel.");
            length = check ask("Select option number");
        }
        if length == "2" {
            timeSlot = check promptTimeSlot();
        }
    }

    string dueDate = check ask(scheduleType == "BOOKING" ? "Booking date (YYYY-MM-DD)" : "Due date (YYYY-MM-DD)");
    string description = check ask("Description");

    // Checked here as well as on the server so an obvious typo costs no round trip.
    if assetTag.length() == 0 {
        io:println("Asset tag is required.");
        return;
    }
    if scheduleId.length() == 0 {
        io:println("Schedule ID is required.");
        return;
    }
    if !isValidDate(dueDate) {
        io:println("Due date must be a real calendar date in YYYY-MM-DD format.");
        return;
    }

    Schedule schedule = {
        scheduleId: scheduleId,
        'type: scheduleType,
        dueDate: dueDate,
        description: description
    };
    if timeSlot is string {
        schedule.timeSlot = timeSlot;
    }

    [int, json]|error result =
        httpPost("/assets/" + assetTag + "/schedules", schedule);

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [status, body] = result;

    if status == 200 || status == 201 {
        io:println("Schedule added successfully.");
    } else {
        printApiError(status, body);
    }
}

function removeSchedule() {
    string assetTag = prompt("Asset tag");
    string scheduleId = prompt("Schedule ID");

    if assetTag.length() == 0 || scheduleId.length() == 0 {
        io:println("Asset tag and schedule ID are both required.");
        return;
    }

    [int, json]|error result =
        httpDelete("/assets/" + assetTag + "/schedules/" + scheduleId);

    if result is error {
        io:println("Request failed: " + result.message());
        return;
    }

    var [status, body] = result;

    if status == 200 {
        io:println("Schedule removed successfully.");
    } else {
        printApiError(status, body);
    }
}

function selectScheduleType() returns string|CancelError {
    io:println("Type:");
    io:println("  1. Booking");
    io:println("  2. Servicing (maintenance)");
    io:println("  0. Cancel");
    while true {
        match check ask("Select type number") {
            "1" => { return "BOOKING"; }
            "2" => { return "MAINTENANCE"; }
            _ => { io:println("Please enter 1, 2 or 0 to cancel."); }
        }
    }
}

// Keeps asking until a valid HH:MM-HH:MM slot is entered.
function promptTimeSlot() returns string|CancelError {
    while true {
        string entered = (check ask("Time slot (HH:MM-HH:MM, e.g. 12:00-15:00)")).trim();
        if isValidTimeSlot(entered) {
            return entered;
        }
        io:println("Invalid time slot '" + entered +
                "'. Use 24-hour HH:MM-HH:MM with the end after the start, e.g. 12:00-15:00.");
    }
}

// "BOOKING on 2026-10-01 12:00-15:00", "BOOKING on 2026-10-01 (full day)",
// or "MAINTENANCE due 2026-10-01".
function describeSchedule(Schedule s) returns string {
    if s.'type != "BOOKING" {
        return s.'type + " due " + s.dueDate;
    }
    string? slot = s.timeSlot;
    return "BOOKING on " + s.dueDate + (slot is string ? " " + slot : " (full day)");
}
