import ballerina/http;
import ballerina/io;

public type Component record {|
string compId;
string name;
string description;
|};

public type Schedule record {|
    string scheduleId;
    string 'type; // MAINTENANCE | BOOKING
    string dueDate; // ISO date, e.g. "2026-09-01"
    string description;
    string timeSlot?; // bookings within a day only, e.g. "12:00-15:00"
|};

public type WorkOrderTask record {|
    string taskId;
    string description;
    boolean completed = false;
|};

public type WorkOrder record {|
    string orderId;
    string status; // OPEN | IN_PROGRESS | CLOSED
    string description;
    WorkOrderTask[] tasks = [];
|};

public type Asset record {|
    string assetTag;
    string name;
    string description;
    string institution;
    string site;
    string status; // AVAILABLE | LOANED_OUT | OCCUPIED | UNDER_MAINTENANCE | DISPOSED
    string dateAcquired;
    Component[] components = [];
    Schedule[] schedules = [];
    WorkOrder[] workOrders = [];
|};


// client part idk who doing but i would like too
configurable string serviceUrl = "http://localhost:8080/library";

final http:Client libClient = checkpanic new (serviceUrl);


public function main() returns error? {
    io:println("=======================================================");
    io:println(" Library & Resource Management System — CLI Client");
    io:println(" Connected to: " + serviceUrl);
    io:println("=======================================================");

    boolean running = true;
    while running {
        printMainMenu();
        string choice = io:readln("Select an option: ").trim();
        match choice {
            "1" => { check assetManagementMenu(); }
            "2" => { check viewsMenu(); }
            "3" => { check overdueDashboard(); }
            "4" => { check institutionMenu(); }
            "5" => { check scheduleMenu(); }
            "6" => { check componentMenu(); }
            "7" => { check workOrderMenu(); }
            "8" => { check loanBookFlow(); }
            "0" => {
                running = false;
                io:println("Goodbye!");
            }
            _ => {
                io:println("Invalid option, please try again.");
            }
        }
    }
}


function printMainMenu() {
    io:println("\n--------------------- MAIN MENU ----------------------");
    io:println("1. Asset Management (create / view / update / delete)");
    io:println("2. Views (global list, by institution, site, status)");
    io:println("3. Overdue Dashboard");
    io:println("4. Institution Management");
    io:println("5. Schedule Manager");
    io:println("6. Component Management");
    io:println("7. Work Orders & Tasks");
    io:println("8. Loan an Asset / Book a Room or Lab");
    io:println("0. Exit");
    io:println("--------------------------------------------------------");
}

// Small input helpers — used across every feature file


function prompt(string label) returns string {
    return io:readln(label + ": ").trim();
}

function promptWithDefault(string label, string current) returns string {
    string entered = io:readln(label + " [" + current + "]: ").trim();
    return entered.length() == 0 ? current : entered;
}


// Printing helpers — used across every feature file


function printAssetSummary(Asset a) {
    io:println("  " + a.assetTag + " | " + a.name + " | " + availabilityLabel(a) +
            " | " + a.institution + " | " + a.site);
}

function printAssetDetail(Asset a) {
    io:println("---------------------------------------------------------");
    io:println("Asset Tag     : " + a.assetTag);
    io:println("Name          : " + a.name);
    io:println("Description   : " + a.description);
    io:println("Institution   : " + a.institution);
    io:println("Site          : " + a.site);
    io:println("Status        : " + availabilityLabel(a));
    io:println("Date Acquired : " + isoToDdmmyyyy(a.dateAcquired));

    io:println("Components    : " + a.components.length().toString());
    foreach Component c in a.components {
        io:println("   - [" + c.compId + "] " + c.name + " - " + c.description);
    }

    io:println("Schedules     : " + a.schedules.length().toString());
    foreach Schedule s in a.schedules {
        io:println("   - [" + s.scheduleId + "] " + describeSchedule(s) + " - " + s.description);
    }

    io:println("Work Orders   : " + a.workOrders.length().toString());
    foreach WorkOrder wo in a.workOrders {
        io:println("   - [" + wo.orderId + "] " + wo.status + " - " + wo.description);
        foreach WorkOrderTask t in wo.tasks {
            string done = t.completed ? "done" : "pending";
            io:println("        * [" + t.taskId + "] " + t.description + " (" + done + ")");
        }
    }
    io:println("---------------------------------------------------------");
}

function printAssetList(Asset[] assets) {
    if assets.length() == 0 {
        io:println("(no assets found)");
        return;
    }
    foreach Asset a in assets {
        printAssetSummary(a);
    }
}

// the code below is shared. fetch a single asset by tag, it is used by asset.bal, shcedules.bal and loan_book

function fetchAsset(string assetTag) returns Asset? {
    [int, json]|error result = httpGet("/assets/" + assetTag);
    if result is error {
        io:println("Request failed: " + result.message());
        return ();
    }
    var [status, body] = result;
    if status == 200 {
        Asset|error a = body.cloneWithType(Asset);
        if a is error {
            io:println("Failed to parse asset: " + a.message());
            return ();
        }
        return a;
    }
    printApiError(status, body);
    return ();
}


// Cancelling: typing 0 at any prompt inside an add/update flow abandons it.
type CancelError distinct error;

function ask(string label) returns string|CancelError {
    string value = prompt(label);
    if value == "0" {
        return error CancelError("cancelled");
    }
    return value;
}

function askWithDefault(string label, string current) returns string|CancelError {
    string value = promptWithDefault(label, current);
    if value == "0" {
        return error CancelError("cancelled");
    }
    return value;
}

// Reports how an add/update flow ended; a cancel just returns to the menu.
function finish(error? result) {
    if result is CancelError {
        io:println("Cancelled - nothing was saved.");
    } else if result is error {
        io:println(result.message());
    }
}
