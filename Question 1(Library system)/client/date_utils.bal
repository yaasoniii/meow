import ballerina/io;
import ballerina/time;

// Shared date helpers. ISO dates are zero-padded, so comparing them as plain
// strings gives the same ordering as comparing the dates themselves.
// These mirror the checks in the service so the client can catch a bad date
// before spending a round trip on it.

function todayIso() returns string {
    return time:utcToString(time:utcNow()).substring(0, 10);
}

function isValidDate(string date) returns boolean {
    if date.length() != 10 {
        return false;
    }
    if date.substring(4, 5) != "-" || date.substring(7, 8) != "-" {
        return false;
    }
    int|error year = int:fromString(date.substring(0, 4));
    int|error month = int:fromString(date.substring(5, 7));
    int|error day = int:fromString(date.substring(8, 10));
    if year is error || month is error || day is error {
        return false;
    }
    if month < 1 || month > 12 || day < 1 {
        return false;
    }
    return day <= daysInMonth(month, year);
}

function daysInMonth(int month, int year) returns int {
    if month == 1 || month == 3 || month == 5 || month == 7
            || month == 8 || month == 10 || month == 12 {
        return 31;
    }
    if month == 4 || month == 6 || month == 9 || month == 11 {
        return 30;
    }
    return isLeapYear(year) ? 29 : 28;
}

function isLeapYear(int year) returns boolean {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}

// Asset dates are typed as DD-MM-YYYY but stored as ISO (YYYY-MM-DD).
// Returns the ISO form, or () if the input is not a real DD-MM-YYYY date.
function ddmmyyyyToIso(string date) returns string? {
    string d = date.trim();
    if d.length() != 10 || d.substring(2, 3) != "-" || d.substring(5, 6) != "-" {
        return ();
    }
    string iso = d.substring(6, 10) + "-" + d.substring(3, 5) + "-" + d.substring(0, 2);
    return isValidDate(iso) ? iso : ();
}

function isoToDdmmyyyy(string iso) returns string {
    if !isValidDate(iso) {
        return iso;
    }
    return iso.substring(8, 10) + "-" + iso.substring(5, 7) + "-" + iso.substring(0, 4);
}

// Keeps asking until a valid DD-MM-YYYY date is entered (0 cancels). With a
// current value, pressing Enter keeps it.
function promptDate(string label, string? current = ()) returns string|CancelError {
    while true {
        string fullLabel = label + " (DD-MM-YYYY, e.g. 20-06-2024)";
        string entered = current is string ? check askWithDefault(fullLabel, current) : check ask(fullLabel);
        string? iso = ddmmyyyyToIso(entered);
        if iso is string {
            return iso;
        }
        io:println("Invalid date '" + entered + "'. Please use the format DD-MM-YYYY, e.g. 15-03-2024.");
    }
}

// "HH:MM-HH:MM" in 24-hour time, with the end after the start. Zero-padded
// times compare correctly as plain strings.
function isValidTimeSlot(string slot) returns boolean {
    if slot.length() != 11 || slot.substring(5, 6) != "-" {
        return false;
    }
    string 'start = slot.substring(0, 5);
    string end = slot.substring(6, 11);
    return isValidTime('start) && isValidTime(end) && 'start < end;
}

function isValidTime(string t) returns boolean {
    if t.length() != 5 || t.substring(2, 3) != ":" {
        return false;
    }
    int|error h = int:fromString(t.substring(0, 2));
    int|error m = int:fromString(t.substring(3, 5));
    return h is int && m is int && h >= 0 && h <= 23 && m >= 0 && m <= 59;
}
